public struct DictationStateMachine: Sendable, Equatable {
    public private(set) var state: DictationState = .idle

    public init(state: DictationState = .idle) {
        self.state = state
    }

    public mutating func transition(to newState: DictationState) throws {
        guard Self.isValid(from: state, to: newState) else {
            throw DictationError.invalidTransition(from: state.name, to: newState.name)
        }
        state = newState
    }

    public mutating func reset() {
        state = .idle
    }

    public mutating func fail(_ error: DictationError) {
        state = .failed(error)
    }

    public mutating func cancel() {
        state = .idle
    }

    public static func isValid(from: DictationState, to: DictationState) -> Bool {
        if to == .idle { return true }
        if case .failed = to {
            return from != .idle
        }

        switch (from, to) {
        case (.idle, .preparing): return true
        case (.preparing, .recording): return true
        case (.recording, .processingAudio): return true
        case (.processingAudio, .transcribing): return true
        case (.transcribing, .rewriting): return true
        case (.transcribing, .inserting): return true
        case (.rewriting, .inserting): return true
        case (.inserting, .completed): return true
        case (.completed, .idle): return true
        case (.failed, .idle): return true
        default: return false
        }
    }
}
