public enum DictationState: Sendable, Equatable {
    case idle
    case preparing
    case recording
    case processingAudio
    case transcribing
    case rewriting
    case inserting
    case completed
    case failed(DictationError)

    public var overlayTitle: String {
        switch self {
        case .idle: "Ready"
        case .preparing: "Starting…"
        case .recording: "Listening…"
        case .processingAudio: "Processing audio…"
        case .transcribing: "Transcribing…"
        case .rewriting: "Cleaning up…"
        case .inserting: "Inserting…"
        case .completed: "Done"
        case .failed(let error): error.userMessage
        }
    }

    public var name: String {
        switch self {
        case .idle: "idle"
        case .preparing: "preparing"
        case .recording: "recording"
        case .processingAudio: "processingAudio"
        case .transcribing: "transcribing"
        case .rewriting: "rewriting"
        case .inserting: "inserting"
        case .completed: "completed"
        case .failed: "failed"
        }
    }
}
