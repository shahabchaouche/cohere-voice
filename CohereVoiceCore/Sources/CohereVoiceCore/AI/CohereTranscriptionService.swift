import Foundation

public struct CohereTranscriptionService: TranscriptionService {
    private let client: APIClient
    private let language: @Sendable () -> String

    public init(client: APIClient, language: @escaping @Sendable () -> String = { "en" }) {
        self.client = client
        self.language = language
    }

    public func transcribe(_ audio: RecordedAudio) async throws -> Transcript {
        var form = MultipartForm()
        form.addField(name: "model", value: CohereModels.transcribe)
        form.addField(name: "language", value: language())
        form.addFile(name: "file", filename: "audio.wav", mimeType: "audio/wav", data: audio.wavData)

        let request = APIRequest(
            path: "/v2/audio/transcriptions",
            headers: ["Content-Type": form.contentType],
            body: form.encode()
        )

        do {
            let data = try await client.send(request)
            let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            let text = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw DictationError.emptySpeech }
            return Transcript(text: text)
        } catch let error as APIError {
            throw error.asDictationError(for: .transcription)
        } catch let error as DictationError {
            throw error
        } catch {
            throw DictationError.transcriptionFailed(nil)
        }
    }
}

private struct TranscriptionResponse: Decodable {
    let text: String
}
