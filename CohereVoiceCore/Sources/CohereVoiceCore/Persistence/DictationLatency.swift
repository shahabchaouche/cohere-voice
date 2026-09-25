public struct DictationLatency: Sendable, Codable, Equatable {
    public var recordingStartupMs: Double?
    public var encodingMs: Double?
    public var transcriptionMs: Double?
    public var rewriteMs: Double?
    public var insertionMs: Double?
    public var totalPostRecordingMs: Double?

    public init(
        recordingStartupMs: Double? = nil,
        encodingMs: Double? = nil,
        transcriptionMs: Double? = nil,
        rewriteMs: Double? = nil,
        insertionMs: Double? = nil,
        totalPostRecordingMs: Double? = nil
    ) {
        self.recordingStartupMs = recordingStartupMs
        self.encodingMs = encodingMs
        self.transcriptionMs = transcriptionMs
        self.rewriteMs = rewriteMs
        self.insertionMs = insertionMs
        self.totalPostRecordingMs = totalPostRecordingMs
    }

    public var rows: [(label: String, milliseconds: Double?)] {
        [
            ("Recording startup", recordingStartupMs),
            ("Audio encoding", encodingMs),
            ("Transcription", transcriptionMs),
            ("Rewrite", rewriteMs),
            ("Insertion", insertionMs),
            ("Total after release", totalPostRecordingMs),
        ]
    }

    public static func format(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded())) ms"
    }
}
