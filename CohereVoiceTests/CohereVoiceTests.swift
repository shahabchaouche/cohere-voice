import Foundation
import Testing
import CohereVoiceCore

struct HotkeyOptionTests {
    @Test func garbageStoredValueFallsBackToOptionSpace() {
        #expect(HotkeyOption.from(stored: "garbage") == .optionSpace)
    }

    @Test func carbonModifiersNilOnlyForFn() {
        #expect(HotkeyOption.optionSpace.carbonModifiers != nil)
        #expect(HotkeyOption.controlSpace.carbonModifiers != nil)
        #expect(HotkeyOption.commandShiftSpace.carbonModifiers != nil)
        #expect(HotkeyOption.fn.carbonModifiers == nil)
    }
}

@MainActor
struct AppSettingsTests {
    @Test func persistsLanguageAndHotkey() {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let settings = AppSettings(store: SettingsStore(defaults: defaults))
        settings.language = .french
        settings.hotkey = .controlSpace
        let reloaded = AppSettings(store: SettingsStore(defaults: defaults))
        #expect(reloaded.language == .french)
        #expect(reloaded.hotkey == .controlSpace)
        defaults.removePersistentDomain(forName: suiteName)
    }
}
