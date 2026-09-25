/// Languages Cohere Transcribe accepts (`language` is required; no auto-detect).
public enum TranscriptionLanguage: String, CaseIterable, Identifiable, Sendable, Codable {
    case english = "en"
    case german = "de"
    case french = "fr"
    case italian = "it"
    case spanish = "es"
    case portuguese = "pt"
    case greek = "el"
    case dutch = "nl"
    case polish = "pl"
    case vietnamese = "vi"
    case chinese = "zh"
    case arabic = "ar"
    case japanese = "ja"
    case korean = "ko"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .english: "English"
        case .german: "German"
        case .french: "French"
        case .italian: "Italian"
        case .spanish: "Spanish"
        case .portuguese: "Portuguese"
        case .greek: "Greek"
        case .dutch: "Dutch"
        case .polish: "Polish"
        case .vietnamese: "Vietnamese"
        case .chinese: "Chinese"
        case .arabic: "Arabic"
        case .japanese: "Japanese"
        case .korean: "Korean"
        }
    }

    public static func from(stored: String) -> TranscriptionLanguage {
        TranscriptionLanguage(rawValue: stored) ?? .english
    }
}
