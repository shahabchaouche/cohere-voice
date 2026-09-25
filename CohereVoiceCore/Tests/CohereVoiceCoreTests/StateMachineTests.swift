import Testing
@testable import CohereVoiceCore

struct StateMachineTests {
    @Test func happyPath() throws {
        var machine = DictationStateMachine()
        try machine.transition(to: .preparing)
        try machine.transition(to: .recording)
        try machine.transition(to: .processingAudio)
        try machine.transition(to: .transcribing)
        try machine.transition(to: .rewriting)
        try machine.transition(to: .inserting)
        try machine.transition(to: .completed)
        try machine.transition(to: .idle)
        #expect(machine.state == .idle)
    }

    @Test func canSkipRewriteToInsert() throws {
        var machine = DictationStateMachine()
        try machine.transition(to: .preparing)
        try machine.transition(to: .recording)
        try machine.transition(to: .processingAudio)
        try machine.transition(to: .transcribing)
        try machine.transition(to: .inserting)
        #expect(machine.state == .inserting)
    }

    @Test func invalidTransitionThrows() {
        var machine = DictationStateMachine()
        do {
            try machine.transition(to: .recording)
            Issue.record("expected invalid transition")
        } catch let error as DictationError {
            guard case .invalidTransition = error else {
                Issue.record("wrong error \(error)")
                return
            }
        } catch {
            Issue.record("unexpected \(error)")
        }
    }

    @Test func cancelFromAnyState() throws {
        var machine = DictationStateMachine()
        try machine.transition(to: .preparing)
        try machine.transition(to: .recording)
        machine.cancel()
        #expect(machine.state == .idle)
    }

    @Test func failureThenIdle() throws {
        var machine = DictationStateMachine()
        try machine.transition(to: .preparing)
        machine.fail(.emptySpeech)
        #expect(machine.state == .failed(.emptySpeech))
        try machine.transition(to: .idle)
        #expect(machine.state == .idle)
    }
}
