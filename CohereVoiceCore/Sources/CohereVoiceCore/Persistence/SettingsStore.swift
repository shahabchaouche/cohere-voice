import Foundation

public struct AppPreferences: Sendable, Equatable, Codable {
    public var mode: DictationMode
    public var hotkey: String
    public var language: String
    public var historyEnabled: Bool
    public var saveRecordings: Bool
    public var dictionaryTerms: [String]
    public var hasCompletedOnboarding: Bool
    public var rewriteEnabled: Bool
    public var includeSelectedTextInRewrite: Bool

    public var shouldCaptureSelectedText: Bool {
        rewriteEnabled && includeSelectedTextInRewrite
    }

    public static let `default` = AppPreferences(
        mode: .standard,
        hotkey: "optionSpace",
        language: "en",
        historyEnabled: true,
        saveRecordings: false,
        dictionaryTerms: [],
        hasCompletedOnboarding: false,
        rewriteEnabled: true,
        includeSelectedTextInRewrite: false
    )

    public init(
        mode: DictationMode,
        hotkey: String,
        language: String,
        historyEnabled: Bool,
        saveRecordings: Bool,
        dictionaryTerms: [String],
        hasCompletedOnboarding: Bool,
        rewriteEnabled: Bool = true,
        includeSelectedTextInRewrite: Bool = false
    ) {
        self.mode = mode
        self.hotkey = hotkey
        self.language = language
        self.historyEnabled = historyEnabled
        self.saveRecordings = saveRecordings
        self.dictionaryTerms = dictionaryTerms
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.rewriteEnabled = rewriteEnabled
        self.includeSelectedTextInRewrite = includeSelectedTextInRewrite
    }

    private enum CodingKeys: String, CodingKey {
        case mode, hotkey, language, historyEnabled, saveRecordings, dictionaryTerms, hasCompletedOnboarding, rewriteEnabled, includeSelectedTextInRewrite
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(DictationMode.self, forKey: .mode)
        hotkey = try container.decode(String.self, forKey: .hotkey)
        language = try container.decode(String.self, forKey: .language)
        historyEnabled = try container.decode(Bool.self, forKey: .historyEnabled)
        saveRecordings = try container.decode(Bool.self, forKey: .saveRecordings)
        dictionaryTerms = try container.decode([String].self, forKey: .dictionaryTerms)
        hasCompletedOnboarding = try container.decode(Bool.self, forKey: .hasCompletedOnboarding)
        rewriteEnabled = try container.decodeIfPresent(Bool.self, forKey: .rewriteEnabled) ?? true
        includeSelectedTextInRewrite = try container.decodeIfPresent(Bool.self, forKey: .includeSelectedTextInRewrite) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(hotkey, forKey: .hotkey)
        try container.encode(language, forKey: .language)
        try container.encode(historyEnabled, forKey: .historyEnabled)
        try container.encode(saveRecordings, forKey: .saveRecordings)
        try container.encode(dictionaryTerms, forKey: .dictionaryTerms)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encode(rewriteEnabled, forKey: .rewriteEnabled)
        try container.encode(includeSelectedTextInRewrite, forKey: .includeSelectedTextInRewrite)
    }
}

public struct SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "coherevoice.preferences"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppPreferences {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data)
        else {
            return .default
        }
        return decoded
    }

    public func save(_ preferences: AppPreferences) {
        if let data = try? JSONEncoder().encode(preferences) {
            defaults.set(data, forKey: key)
        }
    }
}
