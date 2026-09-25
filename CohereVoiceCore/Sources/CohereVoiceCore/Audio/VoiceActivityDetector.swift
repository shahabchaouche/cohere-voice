import Foundation

public struct VADResult: Sendable, Equatable {
    public var isSpeech: Bool
    public var didStart: Bool
    public var didEnd: Bool
    public var hasDetectedSpeech: Bool

    public init(isSpeech: Bool, didStart: Bool, didEnd: Bool, hasDetectedSpeech: Bool) {
        self.isSpeech = isSpeech
        self.didStart = didStart
        self.didEnd = didEnd
        self.hasDetectedSpeech = hasDetectedSpeech
    }
}

public struct VoiceActivityDetector: Sendable {
    public var speechMultiplier: Float
    public var minSpeechDuration: TimeInterval
    public var silenceTimeout: TimeInterval
    public private(set) var noiseFloor: Float
    public private(set) var hasDetectedSpeech = false

    private var speechTime: TimeInterval = 0
    private var silenceTime: TimeInterval = 0
    private var inSpeech = false
    private var calibratedFrames = 0

    public init(
        speechMultiplier: Float = 3.5,
        minSpeechDuration: TimeInterval = 0.12,
        silenceTimeout: TimeInterval = 0.45,
        initialNoiseFloor: Float = 0.004
    ) {
        self.speechMultiplier = speechMultiplier
        self.minSpeechDuration = minSpeechDuration
        self.silenceTimeout = silenceTimeout
        self.noiseFloor = initialNoiseFloor
    }

    public mutating func reset() {
        hasDetectedSpeech = false
        speechTime = 0
        silenceTime = 0
        inSpeech = false
        calibratedFrames = 0
        noiseFloor = 0.004
    }

    public mutating func process(rms: Float, frameDuration: TimeInterval) -> VADResult {
        if !inSpeech && calibratedFrames < 12 {
            let sample = min(max(rms, 0.0008), 0.01)
            noiseFloor = noiseFloor * 0.8 + sample * 0.2
            calibratedFrames += 1
        } else if !inSpeech {
            let sample = min(rms, 0.02)
            noiseFloor = min(noiseFloor * 0.95 + sample * 0.05, 0.03)
        }

        let threshold = max(noiseFloor * speechMultiplier, 0.012)
        let voiced = rms >= threshold

        var didStart = false
        var didEnd = false

        if voiced {
            speechTime += frameDuration
            silenceTime = 0
            if !inSpeech && speechTime >= minSpeechDuration {
                inSpeech = true
                hasDetectedSpeech = true
                didStart = true
            }
        } else {
            silenceTime += frameDuration
            if inSpeech && silenceTime >= silenceTimeout {
                inSpeech = false
                speechTime = 0
                didEnd = true
            } else if !inSpeech {
                speechTime = 0
            }
        }

        return VADResult(
            isSpeech: inSpeech,
            didStart: didStart,
            didEnd: didEnd,
            hasDetectedSpeech: hasDetectedSpeech
        )
    }
}

public enum SilenceTrimmer {
    public static func trim(_ samples: [Float], threshold: Float = 0.01, pad: Int = 1600) -> [Float] {
        guard !samples.isEmpty else { return samples }
        var start = samples.firstIndex { abs($0) >= threshold } ?? 0
        var end = samples.lastIndex { abs($0) >= threshold } ?? (samples.count - 1)
        start = max(0, start - pad)
        end = min(samples.count - 1, end + pad)
        guard start <= end else { return [] }
        return Array(samples[start...end])
    }
}
