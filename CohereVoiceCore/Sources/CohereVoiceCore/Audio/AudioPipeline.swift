import Foundation

public protocol AudioPipeline: Sendable {
    var events: AsyncStream<AudioEvent> { get }
    func start() async throws
    func stop() async throws -> RecordedAudio
}

public actor DefaultAudioPipeline: AudioPipeline {
    public nonisolated let events: AsyncStream<AudioEvent>

    private let engine: AudioEngineManager
    private let eventContinuation: AsyncStream<AudioEvent>.Continuation
    private var consumeTask: Task<Void, Never>?
    private var samples: [Float] = []
    private var sampleRate: Double = 16_000
    private var vad = VoiceActivityDetector()
    private var didDetectSpeech = false
    private var running = false

    public init(engine: AudioEngineManager = AudioEngineManager()) {
        self.engine = engine
        let (stream, continuation) = AsyncStream.makeStream(of: AudioEvent.self)
        self.events = stream
        self.eventContinuation = continuation
    }

    public func start() async throws {
        if running {
            _ = try? await stop()
        }
        samples.removeAll(keepingCapacity: true)
        didDetectSpeech = false
        vad.reset()
        running = true

        let engineEvents = try await engine.start()
        consumeTask = Task { [weak self] in
            for await event in engineEvents {
                guard let self else { break }
                await self.handle(event)
                if Task.isCancelled { break }
            }
        }
    }

    public func stop() async throws -> RecordedAudio {
        running = false
        consumeTask?.cancel()
        consumeTask = nil
        await engine.stop()

        let trimmed = SilenceTrimmer.trim(samples)
        let duration = sampleRate > 0 ? TimeInterval(trimmed.count) / sampleRate : 0
        let wav = try AudioEncoder.encodeWAV(floatMono: trimmed, sourceSampleRate: sampleRate)
        return RecordedAudio(
            wavData: wav,
            duration: duration,
            didDetectSpeech: didDetectSpeech || duration >= 0.3
        )
    }

    private func handle(_ event: EngineEvent) {
        switch event {
        case .chunk(let chunk):
            ingest(chunk)
        case .routeChanged:
            eventContinuation.yield(.routeChanged)
        case .interrupted(let reason):
            CVLog.audio.error("Audio interrupted: \(reason, privacy: .public)")
            eventContinuation.yield(.interrupted)
        }
    }

    private func ingest(_ chunk: PCMChunk) {
        if samples.isEmpty {
            sampleRate = chunk.sampleRate
        }
        let mono = chunk.floatMonoSamples()
        samples.append(contentsOf: mono)
        eventContinuation.yield(.level(min(1, chunk.rms * 4)))

        let vadResult = vad.process(rms: chunk.rms, frameDuration: chunk.frameDuration)
        if vadResult.didStart {
            didDetectSpeech = true
            eventContinuation.yield(.speechStarted)
        }
        if vadResult.didEnd {
            eventContinuation.yield(.speechEnded)
        }
        if vadResult.hasDetectedSpeech {
            didDetectSpeech = true
        }
    }
}
