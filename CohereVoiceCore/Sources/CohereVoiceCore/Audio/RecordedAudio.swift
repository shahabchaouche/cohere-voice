import Foundation

public struct RecordedAudio: Sendable, Equatable {
    public var wavData: Data
    public var duration: TimeInterval
    public var didDetectSpeech: Bool

    public init(
        wavData: Data,
        duration: TimeInterval,
        didDetectSpeech: Bool
    ) {
        self.wavData = wavData
        self.duration = duration
        self.didDetectSpeech = didDetectSpeech
    }

    public var isTooShort: Bool {
        duration < 0.3
    }
}
