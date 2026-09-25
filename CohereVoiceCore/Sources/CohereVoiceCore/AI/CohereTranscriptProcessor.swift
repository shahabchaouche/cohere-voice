import Foundation

public struct CohereTranscriptProcessor: TranscriptProcessor {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func process(
        transcript: Transcript,
        context: DictationContext
    ) async throws -> ProcessedTranscript {
        let payload = ChatRequest(
            model: CohereModels.command,
            messages: [
                .init(role: "system", content: PromptBuilder.systemPrompt(context: context)),
                .init(role: "user", content: transcript.text),
            ],
            temperature: 0.2
        )

        let body = try JSONEncoder().encode(payload)
        let request = APIRequest(
            path: "/v2/chat",
            headers: ["Content-Type": "application/json"],
            body: body
        )

        do {
            let data = try await client.send(request)
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            let text = RewriteSanitizer.sanitize(decoded.bestText)
            guard !text.isEmpty else {
                throw DictationError.rewriteFailed(nil)
            }
            return ProcessedTranscript(text: text)
        } catch let error as APIError {
            throw error.asDictationError(for: .rewrite)
        } catch let error as DictationError {
            throw error
        } catch {
            throw DictationError.rewriteFailed(nil)
        }
    }
}

private struct ChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
}

private struct ChatResponse: Decodable {
    struct Message: Decodable {
        struct ContentBlock: Decodable {
            let type: String?
            let text: String?
        }

        let content: [ContentBlock]?
    }

    let message: Message?

    var bestText: String {
        message?.content?.compactMap(\.text).joined(separator: "") ?? ""
    }
}
