import Testing
@testable import CohereVoiceCore

struct ProcessorFallbackTests {
    @Test func failureReturnsRawTranscript() async throws {
        let processor = FallbackTranscriptProcessor(primary: FailingTranscriptProcessor(message: "private failure detail"))
        let result = try await processor.process(
            transcript: Transcript(text: "hello world"),
            context: DictationContext()
        )
        #expect(result.text == "hello world")
        #expect(result.usedFallback)
        #expect(result.errorDescription == "Rewrite failed; the raw transcript is available.")
    }

    @Test func sanitizerStripsQuotes() {
        #expect(RewriteSanitizer.sanitize("  \"Hey there.\"  ") == "Hey there.")
        #expect(RewriteSanitizer.sanitize("plain") == "plain")
        #expect(RewriteSanitizer.sanitize("\"Hey") == "\"Hey")
        #expect(RewriteSanitizer.sanitize("`code`") == "code")
    }
}
