import Foundation
import Testing
@testable import CohereVoiceCore

@Suite(.serialized)
struct APIClientTests {
    private func makeClient() -> APIClient {
        APIClient(
            keyProvider: StaticKeyProvider(),
            session: MockURLProtocol.makeSession()
        )
    }

    private func ping() -> APIRequest {
        APIRequest(path: "/v2/test", body: Data("ping".utf8))
    }

    @Test func unauthorizedThrowsAuthenticationFailedOnce() async throws {
        try await withIsolatedMockNetwork {
            MockURLProtocol.reset()
            MockURLProtocol.queue = [.success((401, Data("nope".utf8)))]
            let client = makeClient()
            await #expect(throws: APIError.authenticationFailed) {
                _ = try await client.send(ping())
            }
            #expect(MockURLProtocol.requests.count == 1)
        }
    }

    @Test func tooManyRequestsThrowsRateLimited() async throws {
        try await withIsolatedMockNetwork {
            MockURLProtocol.reset()
            MockURLProtocol.queue = [.success((429, Data("slow".utf8)))]
            let client = makeClient()
            await #expect(throws: APIError.rateLimited) {
                _ = try await client.send(ping())
            }
            #expect(MockURLProtocol.requests.count == 1)
        }
    }

    @Test func serverErrorRetriesThenSucceeds() async throws {
        try await withIsolatedMockNetwork {
            MockURLProtocol.reset()
            MockURLProtocol.queue = [
                .success((500, Data("err".utf8))),
                .success((200, Data("ok".utf8))),
            ]
            let client = makeClient()
            let data = try await client.send(ping())
            #expect(String(data: data, encoding: .utf8) == "ok")
            #expect(MockURLProtocol.requests.count == 2)
        }
    }

    @Test func timeoutRetriesThenSucceeds() async throws {
        try await withIsolatedMockNetwork {
            MockURLProtocol.reset()
            MockURLProtocol.queue = [
                .failure(URLError(.timedOut)),
                .success((200, Data("ok".utf8))),
            ]
            let client = makeClient()
            let data = try await client.send(ping())
            #expect(String(data: data, encoding: .utf8) == "ok")
            #expect(MockURLProtocol.requests.count == 2)
        }
    }

    @Test func requestSendsBearerKeyAndUserAgent() async throws {
        try await withIsolatedMockNetwork {
            MockURLProtocol.reset()
            MockURLProtocol.queue = [.success((200, Data("ok".utf8)))]
            let client = makeClient()
            _ = try await client.send(ping())
            let request = try #require(MockURLProtocol.requests.first)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
            #expect(request.value(forHTTPHeaderField: "User-Agent") == "cohere-voice/1.0")
        }
    }
}
