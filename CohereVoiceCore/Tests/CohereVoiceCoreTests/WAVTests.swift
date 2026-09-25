import Testing
import Foundation
@testable import CohereVoiceCore

struct WAVTests {
    @Test func headerMatchesSpec() {
        let pcm = Data([0x00, 0x00, 0x00, 0x10])
        let wav = AudioEncoder.encodeWAV(int16MonoPCM: pcm, sampleRate: 16_000)
        let header = AudioEncoder.parseWAVHeader(wav)
        #expect(header?.audioFormat == 1)
        #expect(header?.channels == 1)
        #expect(header?.sampleRate == 16_000)
        #expect(header?.bitsPerSample == 16)
        #expect(header?.dataSize == 4)
        #expect(wav.count == 48)
        #expect(Array(wav[0..<4]) == Array("RIFF".utf8))
        #expect(Array(wav[8..<12]) == Array("WAVE".utf8))
    }

    @Test func encodesFloatMono() throws {
        let samples = [Float](repeating: 0.25, count: 1600)
        let wav = try AudioEncoder.encodeWAV(floatMono: samples, sourceSampleRate: 16_000)
        let header = try #require(AudioEncoder.parseWAVHeader(wav))
        #expect(header.sampleRate == 16_000)
        #expect(header.dataSize == 3200)
    }
}
