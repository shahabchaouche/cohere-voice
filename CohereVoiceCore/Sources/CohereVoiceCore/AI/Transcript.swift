public struct Transcript: Sendable, Equatable {
    public var text: String

    public init(text: String) {
        self.text = text
    }
}

public struct ProcessedTranscript: Sendable, Equatable {
    public var text: String
    public var usedFallback: Bool
    public var errorDescription: String?

    public init(text: String, usedFallback: Bool = false, errorDescription: String? = nil) {
        self.text = text
        self.usedFallback = usedFallback
        self.errorDescription = errorDescription
    }
}

public enum RewriteSanitizer {
    public static func sanitize(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let pairs: [(Character, Character)] = [
            ("\"", "\""),
            ("“", "”"),
            ("'", "'"),
            ("`", "`"),
        ]
        for (leading, trailing) in pairs {
            if text.count >= 2, text.first == leading, text.last == trailing {
                text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return text
    }
}
