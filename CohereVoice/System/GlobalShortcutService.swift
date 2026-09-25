import AppKit
import Carbon
import CohereVoiceCore

/// Push-to-talk without a system-wide CGEvent tap.
///
/// An active session tap intercepts *every* key. If the callback is slow or the
/// tap thread stalls, the Mac's keyboard queues behind it and appears dead.
/// `RegisterEventHotKey` only claims the one chord (and consumes it) and cannot
/// stall unrelated typing. Fn uses a listen-only `NSEvent` monitor for the same reason.
@MainActor
final class GlobalShortcutService {
    var onDown: (() -> Void)?
    var onUp: (() -> Void)?
    var onCancel: (() -> Void)?

    var hotkey: HotkeyOption = .optionSpace {
        didSet {
            guard running, oldValue != hotkey else { return }
            registerCurrentHotkey()
        }
    }

    /// True when Carbon (or the Fn monitor) successfully claimed the chord.
    private(set) var isRegistered = false
    var registrationMessage: String?

    var recording: Bool = false

    private var running = false
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var fnMonitor: Any?
    private var fnLocalMonitor: Any?
    private var escapeMonitor: Any?
    private var fnWasDown = false
    private var holdPollTimer: Timer?
    private var holdToTalkActive = false

    private let hotKeySignature: OSType = 0x4356484B // 'CVHK'
    private let hotKeyID: UInt32 = 1

    func start() {
        stop()
        running = true
        installHotKeyHandlerIfNeeded()
        registerCurrentHotkey()
        installEscapeMonitor()
    }

    func stop() {
        running = false
        isRegistered = false
        stopHoldPoll()
        unregisterHotKey()
        removeFnMonitor()
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
        fnWasDown = false
        holdToTalkActive = false
    }

    private func installHotKeyHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let status = specs.withUnsafeMutableBufferPointer { buffer -> OSStatus in
            guard let base = buffer.baseAddress else { return OSStatus(eventNotHandledErr) }
            return InstallEventHandler(
                GetApplicationEventTarget(),
                carbonHotKeyHandler,
                2,
                base,
                userData,
                &handlerRef
            )
        }
        if status != noErr {
            CVLog.shortcut.error("InstallEventHandler failed: \(status, privacy: .public)")
        }
    }

    private func registerCurrentHotkey() {
        unregisterHotKey()
        removeFnMonitor()
        fnWasDown = false

        if hotkey == .fn {
            installFnMonitor()
            isRegistered = true
            registrationMessage = "Fn works in other apps only if Input Monitoring is granted."
            return
        }

        guard let modifiers = hotkey.carbonModifiers else { return }
        let id = EventHotKeyID(signature: hotKeySignature, id: hotKeyID)
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            isRegistered = false
            registrationMessage = "Could not register \(hotkey.displayName). It may be reserved — pick another shortcut."
            CVLog.shortcut.error("RegisterEventHotKey failed: \(status, privacy: .public). Shortcut may be reserved by macOS.")
        } else {
            isRegistered = true
            registrationMessage = nil
        }
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    fileprivate func handleHotKeyEvent(_ event: EventRef) -> OSStatus {
        var identifier = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &identifier
        )
        guard status == noErr, identifier.signature == hotKeySignature, identifier.id == hotKeyID else {
            return OSStatus(eventNotHandledErr)
        }

        switch GetEventKind(event) {
        case UInt32(kEventHotKeyPressed):
            beginHoldToTalk()
            return noErr
        case UInt32(kEventHotKeyReleased):
            endHoldToTalk()
            return noErr
        default:
            return OSStatus(eventNotHandledErr)
        }
    }

    /// Listen-only: cannot block the keyboard event stream.
    private func installFnMonitor() {
        fnMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleFnFlags(event)
            }
        }
        fnLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleFnFlags(event)
            }
            return event
        }
    }

    private func removeFnMonitor() {
        if let fnMonitor {
            NSEvent.removeMonitor(fnMonitor)
            self.fnMonitor = nil
        }
        if let fnLocalMonitor {
            NSEvent.removeMonitor(fnLocalMonitor)
            self.fnLocalMonitor = nil
        }
    }

    private func handleFnFlags(_ event: NSEvent) {
        let down = event.modifierFlags.contains(.function)
        if down, !fnWasDown {
            fnWasDown = true
            beginHoldToTalk()
        } else if !down, fnWasDown {
            fnWasDown = false
            endHoldToTalk()
        }
    }

    private func beginHoldToTalk() {
        guard !holdToTalkActive else { return }
        holdToTalkActive = true
        onDown?()
        startHoldPoll()
    }

    private func endHoldToTalk() {
        guard holdToTalkActive else { return }
        holdToTalkActive = false
        stopHoldPoll()
        onUp?()
    }

    /// Carbon sometimes omits `kEventHotKeyReleased`. Polling modifier flags does not
    /// require Input Monitoring and cannot stall the keyboard.
    private func startHoldPoll() {
        stopHoldPoll()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.holdToTalkActive else { return }
                if !self.hotkey.isModifierChordHeld() {
                    self.endHoldToTalk()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        holdPollTimer = timer
    }

    private func stopHoldPoll() {
        holdPollTimer?.invalidate()
        holdPollTimer = nil
    }

    private func installEscapeMonitor() {
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, self.recording, event.keyCode == UInt16(kVK_Escape) else { return }
                self.onCancel?()
            }
        }
    }
}

private func carbonHotKeyHandler(
    _: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    let service = Unmanaged<GlobalShortcutService>.fromOpaque(userData).takeUnretainedValue()
    nonisolated(unsafe) let captured = event
    return MainActor.assumeIsolated {
        service.handleHotKeyEvent(captured)
    }
}
