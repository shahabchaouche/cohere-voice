import CohereVoiceCore

internal struct FailingTranscriptProcessor: TranscriptProcessor {
    var message: String

    init(message: String = "boom") {
        self.message = message
    }

    func process(
        transcript: Transcript,
        context: DictationContext
    ) async throws -> ProcessedTranscript {
        _ = transcript
        _ = context
        throw Failure(message: message)
    }
}

private struct Failure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}
