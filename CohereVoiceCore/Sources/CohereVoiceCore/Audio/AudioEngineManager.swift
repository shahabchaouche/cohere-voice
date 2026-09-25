import AVFoundation
#if os(macOS)
import CoreAudio
#endif

public actor AudioEngineManager {
    /// Created on first `start()`, never in `init`. Constructing `AVAudioEngine`
    /// can trigger the microphone TCC prompt.
    private var engine: AVAudioEngine?
    private var continuation: AsyncStream<EngineEvent>.Continuation?
    private var observers: [NSObjectProtocol] = []
    private var tapInstalled = false
    #if os(macOS)
    private var deviceListenerInstalled = false
    #endif

    public init() {}

    private func makeEngine() -> AVAudioEngine {
        if let engine { return engine }
        let created = AVAudioEngine()
        engine = created
        return created
    }

    public func start() async throws -> AsyncStream<EngineEvent> {
        let engine = makeEngine()
        if engine.isRunning {
            await stop()
        }

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
        #endif

        let (stream, continuation) = AsyncStream.makeStream(of: EngineEvent.self)
        self.continuation = continuation

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw DictationError.engineFailure("Input node reported an invalid format.")
        }

        installObservers(on: engine, continuation: continuation)

        let tapContinuation = continuation
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            guard let chunk = PCMChunk.copy(from: buffer) else { return }
            tapContinuation.yield(.chunk(chunk))
        }
        tapInstalled = true

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            tapInstalled = false
            removeObservers()
            continuation.finish()
            self.continuation = nil
            throw DictationError.engineFailure(error.localizedDescription)
        }

        return stream
    }

    public func stop() async {
        guard let engine else { return }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        if engine.isRunning {
            engine.stop()
        }
        removeObservers()
        continuation?.finish()
        continuation = nil
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
    }

    private func installObservers(on engine: AVAudioEngine, continuation: AsyncStream<EngineEvent>.Continuation) {
        let config = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { _ in
            continuation.yield(.routeChanged)
        }
        observers.append(config)

        #if os(iOS)
        let route = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            continuation.yield(.routeChanged)
        }
        observers.append(route)

        let interruption = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { _ in
            continuation.yield(.interrupted("audio session interruption"))
        }
        observers.append(interruption)
        #endif

        #if os(macOS)
        installDefaultDeviceListener(continuation: continuation)
        #endif
    }

    private func removeObservers() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        #if os(macOS)
        removeDefaultDeviceListener()
        #endif
    }

    #if os(macOS)
    private func installDefaultDeviceListener(continuation: AsyncStream<EngineEvent>.Continuation) {
        guard !deviceListenerInstalled else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main
        ) { _, _ in
            continuation.yield(.routeChanged)
        }
        deviceListenerInstalled = status == noErr
    }

    private func removeDefaultDeviceListener() {
        guard deviceListenerInstalled else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            { _, _ in }
        )
        deviceListenerInstalled = false
    }
    #endif
}
