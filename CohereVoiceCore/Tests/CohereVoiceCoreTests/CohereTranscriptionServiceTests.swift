import Foundation
import Testing
@testable import CohereVoiceCore

@Suite(.serialized)
struct CohereTranscriptionServiceTests {
    private func makeService(language: String = "en") -> CohereTranscriptionService {
        let client = APIClient(
            keyProvider: StaticKeyProvider(),
            session: MockURLProtocol.makeSession()
        )
        return CohereTranscriptionService(client: client) { language }
    }

    private func sampleAudio() -> RecordedAudio {
        RecordedAudio(wavData: Data([1, 2]), duration: 1, didDetectSpeech: true)
    }

    @Test func trimsTranscriptText() async throws {
        try await withIsolatedMockNetwork {
            MockURLProtocol.reset()
            MockURLProtocol.queue = [.success((200, Data(#"{"text":"  hello world \n"}"#.utf8)))]
            let transcript = try await makeService().transcribe(sampleAudio())
            #expect(transcript.text == "hello world")
        }
    }

    @Test func emptyTranscriptThrows() async throws {
        try await withIsolatedMockNetwork {
            MockURLProtocol.reset()
            MockURLProtocol.queue = [.success((200, Data(#"{"text":""}"#.utf8)))]
            await #expect(throws: DictationError.emptySpeech) {
                _ = try await makeService().transcribe(sampleAudio())
            }
        }
    }

    @Test func serverFailureDoesNotClaimRawTextWasInserted() async throws {
        try await withIsolatedMockNetwork {
            MockURLProtocol.reset()
            let body = Data("private server detail".utf8)
            MockURLProtocol.queue = [.success((500, body)), .success((500, body))]
            await #expect(throws: DictationError.transcriptionFailed(500)) {
                _ = try await makeService().transcribe(sampleAudio())
            }
            let message = DictationError.transcriptionFailed(500).userMessage
            #expect(message.contains("No text was inserted"))
            #expect(!message.contains("private server detail"))
        }
    }

    @Test func frenchRequestUsesTranscribePathAndFields() async throws {
        try await withIsolatedMockNetwork {
            MockURLProtocol.reset()
            MockURLProtocol.queue = [.success((200, Data(#"{"text":"bonjour"}"#.utf8)))]
            _ = try await makeService(language: "fr").transcribe(sampleAudio())
            let request = try #require(MockURLProtocol.requests.first)
            #expect(request.url?.path == "/v2/audio/transcriptions")
            let body = String(decoding: MockURLProtocol.body(of: request), as: UTF8.self)
            #expect(body.contains("name=\"language\""))
            #expect(body.contains("fr"))
            #expect(body.contains("name=\"model\""))
            #expect(body.contains(CohereModels.transcribe))
        }
    }
}
