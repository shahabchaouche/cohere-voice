import Testing
@testable import CohereVoiceCore

struct VADTests {
    @Test func silentBufferNeverStartsSpeech() {
        var vad = VoiceActivityDetector()
        var sawStart = false
        for _ in 0..<40 {
            let result = vad.process(rms: 0.0004, frameDuration: 0.02)
            if result.didStart { sawStart = true }
        }
        #expect(sawStart == false)
        #expect(vad.hasDetectedSpeech == false)
    }

    @Test func loudBurstStartsThenEnds() {
        var vad = VoiceActivityDetector(minSpeechDuration: 0.08, silenceTimeout: 0.1)
        var started = false
        var ended = false
        for _ in 0..<8 {
            let result = vad.process(rms: 0.2, frameDuration: 0.02)
            if result.didStart { started = true }
        }
        for _ in 0..<12 {
            let result = vad.process(rms: 0.0002, frameDuration: 0.02)
            if result.didEnd { ended = true }
        }
        #expect(started)
        #expect(ended)
        #expect(vad.hasDetectedSpeech)
    }

    @Test func trimRemovesLeadingAndTrailingSilence() {
        var samples = [Float](repeating: 0, count: 4000)
        for index in 1000..<1200 { samples[index] = 0.4 }
        let trimmed = SilenceTrimmer.trim(samples, threshold: 0.05, pad: 10)
        #expect(trimmed.count < samples.count)
        #expect(trimmed.contains { abs($0) > 0.3 })
        #expect(trimmed.first.map(abs) != 0.4 || trimmed.count > 200)
    }
}
