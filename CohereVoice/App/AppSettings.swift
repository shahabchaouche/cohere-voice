import Foundation
import Observation
import CohereVoiceCore

@MainActor
@Observable
final class AppSettings {
    var preferences: AppPreferences {
        didSet { store.save(preferences) }
    }

    var mode: DictationMode {
        get { preferences.mode }
        set { preferences.mode = newValue }
    }

    var hotkey: HotkeyOption {
        get { HotkeyOption.from(stored: preferences.hotkey) }
        set { preferences.hotkey = newValue.rawValue }
    }

    var language: TranscriptionLanguage {
        get { TranscriptionLanguage.from(stored: preferences.language) }
        set { preferences.language = newValue.rawValue }
    }

    var historyEnabled: Bool {
        get { preferences.historyEnabled }
        set { preferences.historyEnabled = newValue }
    }

    var saveRecordings: Bool {
        get { preferences.saveRecordings }
        set { preferences.saveRecordings = newValue }
    }

    var dictionaryTerms: [String] {
        get { preferences.dictionaryTerms }
        set { preferences.dictionaryTerms = newValue }
    }

    var hasCompletedOnboarding: Bool {
        get { preferences.hasCompletedOnboarding }
        set { preferences.hasCompletedOnboarding = newValue }
    }

    var rewriteEnabled: Bool {
        get { preferences.rewriteEnabled }
        set { preferences.rewriteEnabled = newValue }
    }

    var includeSelectedTextInRewrite: Bool {
        get { preferences.includeSelectedTextInRewrite }
        set { preferences.includeSelectedTextInRewrite = newValue }
    }

    var shouldCaptureSelectedText: Bool {
        preferences.shouldCaptureSelectedText
    }

    private let store: SettingsStore

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
        self.preferences = store.load()
    }
}
