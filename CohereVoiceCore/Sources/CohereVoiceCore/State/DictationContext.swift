public enum AppStyleHint: String, Codable, Sendable, Equatable {
    case conversational
    case email
    case technical
    case browser
    case neutral

    public var promptInstruction: String {
        switch self {
        case .conversational:
            "Format as a casual chat message: short sentences, natural tone, no greeting block unless the speaker used one."
        case .email:
            "Format as a short email when the speech is an email: greeting on its own line, then a blank line, then the body. Keep it concise."
        case .technical:
            "The user is in a developer tool. Preserve technical terminology. Wrap filenames, symbols, and APIs in backticks. Infer whether they are speaking prose about code versus dictating literal code; only output source code when they are clearly dictating code."
        case .browser:
            "Format as clear written text suitable for a web form or article. Use complete sentences."
        case .neutral:
            "Use clear, natural written prose. Do not add a greeting or email structure unless the speaker used one."
        }
    }

    public static func infer(bundleIdentifier: String?, applicationName: String?) -> AppStyleHint {
        let haystack = [bundleIdentifier, applicationName]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if matches(haystack, ["slack", "messages", "ichat", "tinyspeck"]) {
            return .conversational
        }
        if matches(haystack, ["mail"]) {
            return .email
        }
        if matches(haystack, ["xcode", "cursor", "vscode", "visual studio code", "terminal", "iterm", "codex"]) {
            return .technical
        }
        if matches(haystack, ["safari", "chrome", "firefox", "arc", "brave", "edge"]) {
            return .browser
        }
        return .neutral
    }

    private static func matches(_ haystack: String, _ needles: [String]) -> Bool {
        needles.contains { haystack.contains($0) }
    }
}

public struct DictationContext: Sendable, Equatable {
    public var bundleIdentifier: String?
    public var applicationName: String?
    public var selectedText: String?
    public var includeSelectedText: Bool
    public var mode: DictationMode
    public var dictionaryTerms: [String]
    public var styleHint: AppStyleHint
    public var language: String

    public init(
        bundleIdentifier: String? = nil,
        applicationName: String? = nil,
        selectedText: String? = nil,
        includeSelectedText: Bool = false,
        mode: DictationMode = .standard,
        dictionaryTerms: [String] = [],
        styleHint: AppStyleHint? = nil,
        language: String = "en"
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.applicationName = applicationName
        self.selectedText = selectedText
        self.includeSelectedText = includeSelectedText
        self.mode = mode
        self.dictionaryTerms = dictionaryTerms
        self.styleHint = styleHint ?? AppStyleHint.infer(
            bundleIdentifier: bundleIdentifier,
            applicationName: applicationName
        )
        self.language = language
    }
}
