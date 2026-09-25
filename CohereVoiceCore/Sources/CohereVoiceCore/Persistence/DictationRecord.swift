import Foundation

public struct DictationRecord: Sendable, Codable, Identifiable, Equatable {
    public var id: UUID
    public var createdAt: Date
    public var rawTranscript: String
    public var processedTranscript: String
    public var application: String?
    public var mode: DictationMode
    public var latency: DictationLatency
    public var usedRewriteFallback: Bool

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        rawTranscript: String,
        processedTranscript: String,
        application: String? = nil,
        mode: DictationMode,
        latency: DictationLatency,
        usedRewriteFallback: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.rawTranscript = rawTranscript
        self.processedTranscript = processedTranscript
        self.application = application
        self.mode = mode
        self.latency = latency
        self.usedRewriteFallback = usedRewriteFallback
    }
}
