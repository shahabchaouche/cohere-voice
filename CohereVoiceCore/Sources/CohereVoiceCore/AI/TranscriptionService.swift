public protocol TranscriptionService: Sendable {
    func transcribe(_ audio: RecordedAudio) async throws -> Transcript
}
