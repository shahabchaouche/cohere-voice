import AppKit
import AVFoundation
import ApplicationServices

@MainActor
@Observable
final class PermissionService {
    var microphoneGranted = false
    var accessibilityGranted = false
    var onUpdate: (@MainActor () -> Void)?

    func refresh() {
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        accessibilityGranted = AXIsProcessTrusted()
        onUpdate?()
    }

    var allGranted: Bool {
        microphoneGranted
    }

    var bundlePath: String {
        Bundle.main.bundleURL.path
    }

    private var activationObserver: NSObjectProtocol?

    func startObserving() {
        refresh()
        guard activationObserver == nil else { return }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let bundleID = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated {
                guard bundleID == Bundle.main.bundleIdentifier else { return }
                self?.refresh()
            }
        }
    }

    func recheck() {
        refresh()
    }

    private static func trusted(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func requestMicrophone() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            microphoneGranted = true
            onUpdate?()
            return true
        case .notDetermined:
            NSApp.activate(ignoringOtherApps: true)
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            microphoneGranted = granted
            onUpdate?()
            return granted
        default:
            microphoneGranted = false
            onUpdate?()
            NSApp.activate(ignoringOtherApps: true)
            openMicrophoneSettings()
            return false
        }
    }

    func requestAccessibility() {
        // Header comment on AXIsProcessTrustedWithOptions: prompting is asynchronous
        // and does not change the return value. This call only raises the system dialog.
        // The chip changes when a later AXIsProcessTrusted() call returns true.
        if Self.trusted(prompt: true) {
            accessibilityGranted = true
        }
        onUpdate?()
    }

    func openMicrophoneSettings() {
        open("x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Microphone")
    }

    func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")
    }

    private func open(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
