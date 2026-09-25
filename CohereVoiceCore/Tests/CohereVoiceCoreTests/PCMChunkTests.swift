import AVFoundation
import Testing
@testable import CohereVoiceCore

struct PCMChunkTests {
    @Test func stereoOppositeChannelsCancelToSilence() throws {
        let format = try #require(
            AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 2, interleaved: false)
        )
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480))
        buffer.frameLength = 480
        let left = try #require(buffer.floatChannelData?[0])
        let right = try #require(buffer.floatChannelData?[1])
        for frame in 0..<480 {
            left[frame] = 0.5
            right[frame] = -0.5
        }
        let chunk = try #require(PCMChunk.copy(from: buffer))
        let mono = chunk.floatMonoSamples()
        #expect(mono.count == 480)
        #expect(mono.allSatisfy { abs($0) < 1e-6 })
        #expect(abs(chunk.rms) < 1e-6)
    }

    @Test func monoConstantHasExpectedRMSAndDuration() throws {
        let format = try #require(
            AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false)
        )
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480))
        buffer.frameLength = 480
        let samples = try #require(buffer.floatChannelData?[0])
        for frame in 0..<480 {
            samples[frame] = 0.5
        }
        let chunk = try #require(PCMChunk.copy(from: buffer))
        #expect(abs(chunk.rms - 0.5) < 1e-6)
        #expect(abs(chunk.frameDuration - 0.01) < 1e-9)
    }
}
