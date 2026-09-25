import CohereVoiceCore

struct StaticKeyProvider: APIKeyProviding {
    func apiKey() async throws -> String { "test-key" }
}
