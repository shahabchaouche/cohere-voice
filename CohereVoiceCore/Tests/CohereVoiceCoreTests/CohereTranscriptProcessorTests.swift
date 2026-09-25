import Foundation
import Testing
@testable import CohereVoiceCore

@Suite(.serialized)
struct CohereTranscriptProcessorTests {
    private func makeProcessor() -> CohereTranscriptProcessor {
        let client = APIClient(
            keyProvider: StaticKeyProvider(),
            session: MockURLProtocol.makeSession()
        )
        return CohereTranscriptProcessor(client: client)
    }

    @Test func stripsQuotedRewrite() async throws {
        try await withIsolatedMockNetwork {
            MockURLProtocol.reset()
            let payload = #"{"message":{"content":[{"type":"text","text":"\"Hey Sarah.\""}]}}"#
            MockURLProtocol.queue = [.success((200, Data(payload.utf8)))]
            let result = try await makeProcessor().process(
                transcript: Transcript(text: "hey sarah"),
                context: DictationContext()
            )
            #expect(result.text == "Hey Sarah.")
        }
    }

    @Test func emptyContentThrows() async throws {
        try await withIsolatedMockNetwork {
            MockURLProtocol.reset()
            MockURLProtocol.queue = [.success((200, Data(#"{"message":{"content":[]}}"#.utf8)))]
            await #expect(throws: DictationError.rewriteFailed(nil)) {
                _ = try await makeProcessor().process(
                    transcript: Transcript(text: "hey"),
                    context: DictationContext()
                )
            }
        }
    }

    @Test func serverFailureFallsBackWithoutExposingResponseBody() async throws {
        try await withIsolatedMockNetwork {
            MockURLProtocol.reset()
            let body = Data("private server detail".utf8)
            MockURLProtocol.queue = [.success((500, body)), .success((500, body))]
            let processor = FallbackTranscriptProcessor(primary: makeProcessor())
            let result = try await processor.process(
                transcript: Transcript(text: "raw words"),
                context: DictationContext()
            )
            #expect(result.usedFallback)
            #expect(result.text == "raw words")
            #expect(result.errorDescription == "Rewrite failed; the raw transcript is available.")
            #expect(!result.errorDescription!.contains("private server detail"))
        }
    }

    @Test func requestJSONMatchesCommandContract() async throws {
        try await withIsolatedMockNetwork {
            MockURLProtocol.reset()
            let payload = #"{"message":{"content":[{"type":"text","text":"Hello."}]}}"#
            MockURLProtocol.queue = [.success((200, Data(payload.utf8)))]
            _ = try await makeProcessor().process(
                transcript: Transcript(text: "hello there"),
                context: DictationContext()
            )
            let request = try #require(MockURLProtocol.requests.first)
            let json = try #require(
                JSONSerialization.jsonObject(with: MockURLProtocol.body(of: request)) as? [String: Any]
            )
            #expect(json["model"] as? String == CohereModels.command)
            let messages = try #require(json["messages"] as? [[String: Any]])
            #expect(messages[0]["role"] as? String == "system")
            #expect(messages[1]["content"] as? String == "hello there")
            #expect((json["temperature"] as? NSNumber)?.doubleValue == 0.2)
        }
    }

    @Test func selectedTextOnlyEntersRequestWithOptIn() async throws {
        try await withIsolatedMockNetwork {
            MockURLProtocol.reset()
            let response = Data(#"{"message":{"content":[{"type":"text","text":"Hello."}]}}"#.utf8)
            MockURLProtocol.queue = [.success((200, response)), .success((200, response))]
            let transcript = Transcript(text: "hello")
            let processor = makeProcessor()
            _ = try await processor.process(
                transcript: transcript,
                context: DictationContext(selectedText: "private selection")
            )
            _ = try await processor.process(
                transcript: transcript,
                context: DictationContext(selectedText: "private selection", includeSelectedText: true)
            )
            let first = try #require(MockURLProtocol.requests.first)
            let last = try #require(MockURLProtocol.requests.last)
            #expect(!String(decoding: MockURLProtocol.body(of: first), as: UTF8.self).contains("private selection"))
            #expect(String(decoding: MockURLProtocol.body(of: last), as: UTF8.self).contains("private selection"))
        }
    }
}
