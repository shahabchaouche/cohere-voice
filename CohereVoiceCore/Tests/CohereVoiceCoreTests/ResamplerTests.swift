import Foundation
import Testing
@testable import CohereVoiceCore

struct ResamplerTests {
    @Test func passthrough16k() throws {
        let samples = (0..<160).map { index in Float(index % 7) / 10 }
        let data = try AudioResampler.resampleTo16kMonoInt16(samples: samples, sourceSampleRate: 16_000)
        #expect(data.count == samples.count * 2)
    }

    @Test func downsamples48k() throws {
        let samples = [Float](repeating: 0.1, count: 4800)
        let data = try AudioResampler.resampleTo16kMonoInt16(samples: samples, sourceSampleRate: 48_000)
        #expect(data.count > 2_400)
        #expect(data.count < 3_800)
    }

    @Test func rejectsInvalidRate() throws {
        do {
            _ = try AudioResampler.resampleTo16kMonoInt16(samples: [0.1], sourceSampleRate: 0)
            Issue.record("expected unsupportedFormat")
        } catch let error as DictationError {
            #expect(error == .unsupportedFormat)
        }
    }
}
