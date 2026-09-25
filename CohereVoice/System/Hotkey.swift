import AppKit
import Carbon.HIToolbox

enum HotkeyOption: String, CaseIterable, Identifiable, Sendable {
    case optionSpace
    case controlSpace
    case commandShiftSpace
    case fn

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .optionSpace: "⌥ Space"
        case .controlSpace: "⌃ Space"
        case .commandShiftSpace: "⌘ ⇧ Space"
        case .fn: "Fn / Globe"
        }
    }

    var requiresFnHint: Bool { self == .fn }

    func isModifierChordHeld() -> Bool {
        let flags = CGEventSource.flagsState(.hidSystemState)
        switch self {
        case .optionSpace:
            return flags.contains(.maskAlternate)
        case .controlSpace:
            return flags.contains(.maskControl)
        case .commandShiftSpace:
            return flags.contains(.maskCommand) && flags.contains(.maskShift)
        case .fn:
            return flags.contains(.maskSecondaryFn)
        }
    }

    /// Carbon modifier mask for `RegisterEventHotKey`. Fn cannot be registered this way.
    var carbonModifiers: UInt32? {
        switch self {
        case .optionSpace: UInt32(optionKey)
        case .controlSpace: UInt32(controlKey)
        case .commandShiftSpace: UInt32(cmdKey | shiftKey)
        case .fn: nil
        }
    }

    static func from(stored: String) -> HotkeyOption {
        HotkeyOption(rawValue: stored) ?? .optionSpace
    }
}
