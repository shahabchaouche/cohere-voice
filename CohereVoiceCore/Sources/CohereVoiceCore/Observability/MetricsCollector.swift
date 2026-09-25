public enum LatencyMark: String, Sendable, CaseIterable {
    case shortcutDown
    case engineStarted
    case recordingStopped
    case encodingCompleted
    case requestSent
    case transcriptionReturned
    case rewriteReturned
    case textInserted
}

public actor MetricsCollector {
    private var marks: [LatencyMark: ContinuousClock.Instant] = [:]

    public init() {}

    public func reset() {
        marks.removeAll(keepingCapacity: true)
    }

    public func mark(_ mark: LatencyMark) {
        marks[mark] = ContinuousClock.now
    }

    public func snapshot() -> DictationLatency {
        DictationLatency(
            recordingStartupMs: ms(.shortcutDown, .engineStarted),
            encodingMs: ms(.recordingStopped, .encodingCompleted),
            transcriptionMs: ms(.requestSent, .transcriptionReturned),
            rewriteMs: ms(.transcriptionReturned, .rewriteReturned),
            insertionMs: ms(.rewriteReturned, .textInserted),
            totalPostRecordingMs: ms(.recordingStopped, .textInserted)
        )
    }

    private func ms(_ from: LatencyMark, _ to: LatencyMark) -> Double? {
        guard let start = marks[from], let end = marks[to] else { return nil }
        return Double(start.duration(to: end).components.seconds) * 1000
            + Double(start.duration(to: end).components.attoseconds) / 1_000_000_000_000_000
    }
}
