public enum DictationMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case standard
    case developer
    case raw

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .standard: "Standard"
        case .developer: "Developer"
        case .raw: "Raw"
        }
    }
}
