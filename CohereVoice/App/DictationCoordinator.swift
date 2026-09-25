import AppKit
import Foundation
import CohereVoiceCore

@MainActor
final class DictationCoordinator {
    let model: AppModel
    let settings: AppSettings
    let pipeline: DefaultAudioPipeline
    let metrics: MetricsCollector
    let history: DictationHistoryController
    let overlay: OverlayController
    let permissions: PermissionService

    private let applications = ActiveApplicationService()
    private let insertion = TextInsertionService()
    private let keychain = KeychainStore()
    private var machine = DictationStateMachine()

    /// Monotonic id for the current dictation attempt. Handlers captured by an
    /// older attempt compare their id against this and become no-ops, so a
    /// cancelled session can never mutate state owned by its successor.
    private var generation = 0
    /// The current session's work. Successors chain on `prior?.value` so
    /// pipeline start/stop calls are strictly serialized across sessions.
    private var sessionTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var holdStartedAt: ContinuousClock.Instant?
    private var capturedApplication: FocusedApplication?
    private var capturedSelection: String?
    var shortcuts: GlobalShortcutService?

    init(
        model: AppModel,
        settings: AppSettings,
        pipeline: DefaultAudioPipeline,
        metrics: MetricsCollector,
        history: DictationHistoryController,
        overlay: OverlayController,
        permissions: PermissionService
    ) {
        self.model = model
        self.settings = settings
        self.pipeline = pipeline
        self.metrics = metrics
        self.history = history
        self.overlay = overlay
        self.permissions = permissions
    }

    func start() {
        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in self.pipeline.events {
                self.handleAudioEvent(event)
            }
        }
    }

    func handleKeyDown() {
        guard machine.state != .recording else { return }

        generation &+= 1
        let gen = generation
        let prior = sessionTask
        prior?.cancel()
        watchdogTask?.cancel()
        watchdogTask = nil
        if machine.state != .idle {
            machine.reset()
            apply(.idle)
        }

        holdStartedAt = ContinuousClock.now
        capturedApplication = applications.frontmost()
        capturedSelection = settings.shouldCaptureSelectedText
            ? insertion.selectedText().map { String($0.prefix(400)) }
            : nil
        overlay.show(message: "Starting…")
        sessionTask = Task { [weak self] in
            await prior?.value
            await self?.beginRecording(generation: gen)
        }
    }

    func handleKeyUp() {
        switch machine.state {
        case .preparing, .recording:
            break
        default:
            return
        }

        if let start = holdStartedAt,
           start.duration(to: ContinuousClock.now) < .milliseconds(250) {
            cancel()
            return
        }

        let gen = generation
        let prior = sessionTask
        watchdogTask?.cancel()
        watchdogTask = nil
        sessionTask = Task { [weak self] in
            await prior?.value
            await self?.finishAndProcess(generation: gen)
        }
    }

    func cancel() {
        generation &+= 1
        let prior = sessionTask
        prior?.cancel()
        watchdogTask?.cancel()
        watchdogTask = nil
        machine.cancel()
        apply(.idle)
        overlay.hide()
        model.lastError = nil
        sessionTask = Task { [weak self] in
            await prior?.value
            guard let self else { return }
            _ = try? await self.pipeline.stop()
        }
    }

    func debugRecordToggle() {
        if machine.state == .recording {
            handleKeyUp()
        } else {
            handleKeyDown()
        }
    }

    private func beginRecording(generation gen: Int) async {
        guard gen == generation else { return }
        do {
            try transition(to: .preparing)
            apply(.preparing)
            await metrics.reset()
            await metrics.mark(.shortcutDown)

            guard await permissions.requestMicrophone() else {
                throw DictationError.microphonePermissionDenied
            }
            guard gen == generation else { return }
            guard model.hasAPIKey else {
                throw DictationError.missingAPIKey
            }

            try await pipeline.start()
            guard gen == generation else {
                _ = try? await pipeline.stop()
                return
            }
            await metrics.mark(.engineStarted)
            try transition(to: .recording)
            apply(.recording)
            overlay.show(message: "Listening…")
            model.resetLevels()

            watchdogTask?.cancel()
            watchdogTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(300))
                guard let self, gen == self.generation, self.machine.state == .recording else { return }
                self.model.lastError = DictationError.recordingTooLong.userMessage
                self.handleKeyUp()
            }
        } catch is CancellationError {
            await cancelSilently(generation: gen)
        } catch let error as DictationError {
            await fail(error, generation: gen)
        } catch {
            await fail(.engineFailure(error.localizedDescription), generation: gen)
        }
    }

    private func finishAndProcess(generation gen: Int) async {
        guard gen == generation, machine.state == .recording else { return }
        do {
            try transition(to: .processingAudio)
            apply(.processingAudio)
            overlay.show(message: "Processing…")

            let recorded = try await pipeline.stop()
            guard gen == generation else { return }
            await metrics.mark(.recordingStopped)

            if recorded.isTooShort || !recorded.didDetectSpeech {
                throw DictationError.emptySpeech
            }

            if settings.saveRecordings {
                do {
                    _ = try RecordingArchive.save(recorded.wavData)
                } catch {
                    CVLog.session.error("Failed to save recording: \(error.localizedDescription, privacy: .public)")
                }
            }
            await metrics.mark(.encodingCompleted)

            try transition(to: .transcribing)
            apply(.transcribing)
            overlay.show(message: "Transcribing…")

            let client = makeClient()
            let language = settings.language.rawValue
            let transcriber = CohereTranscriptionService(client: client) { language }
            await metrics.mark(.requestSent)
            let transcript = try await transcriber.transcribe(recorded)
            guard gen == generation else { return }
            await metrics.mark(.transcriptionReturned)
            model.lastRawTranscript = transcript.text

            let inserted: String
            let usedFallback: Bool
            if settings.rewriteEnabled {
                try transition(to: .rewriting)
                apply(.rewriting)
                overlay.show(message: "Cleaning up…")

                let processor = FallbackTranscriptProcessor(primary: CohereTranscriptProcessor(client: client))
                let processed = try await processor.process(transcript: transcript, context: currentContext())
                guard gen == generation else { return }
                await metrics.mark(.rewriteReturned)
                model.lastTranscript = processed.text
                inserted = processed.text
                usedFallback = processed.usedFallback
            } else {
                model.lastTranscript = ""
                inserted = transcript.text
                usedFallback = false
            }

            try transition(to: .inserting)
            apply(.inserting)
            overlay.show(message: "Inserting…")
            try insertion.insert(inserted)
            await metrics.mark(.textInserted)
            model.lastError = usedFallback ? "Rewrite failed; the raw transcript was inserted." : nil

            let latency = await metrics.snapshot()
            model.lastLatency = latency
            try transition(to: .completed)
            apply(.completed)

            await history.record(
                raw: transcript.text,
                processed: inserted,
                application: capturedApplication?.name,
                latency: latency,
                usedFallback: usedFallback
            )

            overlay.show(message: "Done")
            try await Task.sleep(for: .milliseconds(700))
            guard gen == generation else { return }
            machine.reset()
            apply(.idle)
            overlay.hide()
        } catch is CancellationError {
            await cancelSilently(generation: gen)
        } catch let error as DictationError {
            await fail(error, generation: gen)
        } catch {
            if (error as NSError) == (DictationErrorBridge.insertionFailed as NSError) {
                await fail(.insertionFailed, generation: gen)
            } else {
                let failure: DictationError
                switch machine.state {
                case .processingAudio:
                    failure = .engineFailure("Could not process the recording.")
                case .transcribing:
                    failure = .transcriptionFailed(nil)
                case .rewriting:
                    failure = .rewriteFailed(nil)
                case .inserting:
                    failure = .insertionFailed
                default:
                    failure = .engineFailure("An unexpected error occurred.")
                }
                await fail(failure, generation: gen)
            }
        }
    }

    private func handleAudioEvent(_ event: AudioEvent) {
        switch event {
        case .level(let value):
            model.pushLevel(value)
            case .speechStarted, .speechEnded:
                break
        case .routeChanged:
            if machine.state == .recording {
                model.lastError = "Microphone changed — finishing this take."
                handleKeyUp()
            }
        case .interrupted:
            if machine.state == .recording {
                let gen = generation
                let prior = sessionTask
                watchdogTask?.cancel()
                watchdogTask = nil
                sessionTask = Task { [weak self] in
                    await prior?.value
                    await self?.fail(.deviceDisconnected, generation: gen)
                }
            }
        }
    }

    private func currentContext() -> DictationContext {
        DictationContext(
            bundleIdentifier: capturedApplication?.bundleIdentifier,
            applicationName: capturedApplication?.name,
            selectedText: settings.shouldCaptureSelectedText ? capturedSelection : nil,
            includeSelectedText: settings.shouldCaptureSelectedText,
            mode: settings.mode,
            dictionaryTerms: settings.dictionaryTerms,
            language: settings.language.rawValue
        )
    }

    private func makeClient() -> APIClient {
        APIClient(keyProvider: KeychainAPIKeyProvider(store: keychain))
    }

    private func cancelSilently(generation gen: Int) async {
        guard gen == generation else { return }
        _ = try? await pipeline.stop()
        guard gen == generation else { return }
        machine.cancel()
        apply(.idle)
        overlay.hide()
    }

    private func fail(_ error: DictationError, generation gen: Int) async {
        guard gen == generation else { return }
        _ = try? await pipeline.stop()
        guard gen == generation else { return }
        machine.fail(error)
        apply(.failed(error))
        if error.isSilentCancel {
            overlay.hide()
            return
        }
        model.lastError = error.userMessage
        overlay.show(message: error.userMessage)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, gen == self.generation else { return }
            if case .failed = self.machine.state {
                self.machine.reset()
                self.apply(.idle)
                self.overlay.hide()
            }
        }
    }

    private func transition(to state: DictationState) throws {
        try machine.transition(to: state)
    }

    private func apply(_ state: DictationState) {
        model.state = state
        model.overlayMessage = state.overlayTitle
        model.overlayVisible = state != .idle
        shortcuts?.recording = state == .recording
    }
}
