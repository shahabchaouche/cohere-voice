public protocol TranscriptProcessor: Sendable {
    func process(
        transcript: Transcript,
        context: DictationContext
    ) async throws -> ProcessedTranscript
}

public struct FallbackTranscriptProcessor: TranscriptProcessor {
    private let primary: any TranscriptProcessor

    public init(primary: any TranscriptProcessor) {
        self.primary = primary
    }

    public func process(
        transcript: Transcript,
        context: DictationContext
    ) async throws -> ProcessedTranscript {
        do {
            return try await primary.process(transcript: transcript, context: context)
        } catch is CancellationError {
            throw CancellationError()
        } catch DictationError.cancelled {
            throw DictationError.cancelled
        } catch {
            return ProcessedTranscript(
                text: transcript.text,
                usedFallback: true,
                errorDescription: "Rewrite failed; the raw transcript is available."
            )
        }
    }
}
