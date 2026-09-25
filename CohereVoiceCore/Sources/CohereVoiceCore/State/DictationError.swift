public enum DictationError: Error, Sendable, Equatable {
    case microphonePermissionDenied
    case noNetwork
    case authenticationFailed
    case timeout
    case rateLimited
    case emptySpeech
    case unsupportedFormat
    case engineFailure(String)
    case deviceDisconnected
    case cancelled
    case transcriptionFailed(Int?)
    case rewriteFailed(Int?)
    case invalidTransition(from: String, to: String)
    case missingAPIKey
    case apiKeyAccessRequired
    case keychainUnavailable
    case insertionFailed
    case recordingTooLong

    public var userMessage: String {
        switch self {
        case .microphonePermissionDenied:
            "Microphone access is required to dictate."
        case .noNetwork:
            "No network connection. Check your internet and try again."
        case .authenticationFailed:
            "Cohere rejected the API key. Check it in Settings."
        case .timeout:
            "The Cohere request timed out. Try a shorter dictation."
        case .rateLimited:
            "Cohere rate-limited this key. Wait a moment and try again."
        case .emptySpeech:
            "No speech detected."
        case .unsupportedFormat:
            "The microphone produced an unsupported audio format."
        case .engineFailure(let detail):
            "The audio engine failed: \(detail)"
        case .deviceDisconnected:
            "The microphone disconnected during recording."
        case .cancelled:
            "Dictation cancelled."
        case .transcriptionFailed(let statusCode):
            if let statusCode {
                "Transcription failed (HTTP \(statusCode)). No text was inserted."
            } else {
                "Transcription failed. No text was inserted."
            }
        case .rewriteFailed(let statusCode):
            if let statusCode {
                "Rewrite failed (HTTP \(statusCode))."
            } else {
                "Rewrite failed."
            }
        case .invalidTransition(let from, let to):
            "Invalid state transition: \(from) → \(to)."
        case .missingAPIKey:
            "Add a Cohere API key in Settings before dictating."
        case .apiKeyAccessRequired:
            "The saved API key needs authorization. Open Settings and choose Repair Access."
        case .keychainUnavailable:
            "Could not read the saved API key. Open Settings and try again."
        case .insertionFailed:
            "Could not insert text into the focused app."
        case .recordingTooLong:
            "Recording reached the 5-minute limit and was submitted."
        }
    }

    public var isSilentCancel: Bool {
        if case .cancelled = self { return true }
        return false
    }
}
