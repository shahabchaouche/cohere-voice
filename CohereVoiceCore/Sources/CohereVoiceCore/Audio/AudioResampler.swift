@preconcurrency import AVFoundation

public enum AudioResampler {
    public static func resampleTo16kMonoInt16(
        samples: [Float],
        sourceSampleRate: Double
    ) throws -> Data {
        guard !samples.isEmpty else { return Data() }
        guard sourceSampleRate > 0 else { throw DictationError.unsupportedFormat }

        if abs(sourceSampleRate - 16_000) < 0.5 {
            return int16Data(from: samples)
        }

        guard
            let sourceFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sourceSampleRate,
                channels: 1,
                interleaved: false
            ),
            let destFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: 16_000,
                channels: 1,
                interleaved: true
            ),
            let converter = AVAudioConverter(from: sourceFormat, to: destFormat)
        else {
            throw DictationError.unsupportedFormat
        }

        guard
            let sourceBuffer = AVAudioPCMBuffer(
                pcmFormat: sourceFormat,
                frameCapacity: AVAudioFrameCount(samples.count)
            )
        else {
            throw DictationError.unsupportedFormat
        }
        sourceBuffer.frameLength = AVAudioFrameCount(samples.count)
        sourceBuffer.floatChannelData?[0].update(from: samples, count: samples.count)

        let ratio = 16_000.0 / sourceSampleRate
        let destFrames = AVAudioFrameCount((Double(samples.count) * ratio).rounded(.up) + 32)
        guard let destBuffer = AVAudioPCMBuffer(pcmFormat: destFormat, frameCapacity: destFrames) else {
            throw DictationError.unsupportedFormat
        }

        var error: NSError?
        let consumed = ConsumedFlag()
        let status = converter.convert(to: destBuffer, error: &error) { _, outStatus in
            if consumed.value {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed.value = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }
        if let error { throw error }
        guard status != .error else { throw DictationError.unsupportedFormat }

        let byteCount = Int(destBuffer.frameLength) * MemoryLayout<Int16>.size
        guard let pointer = destBuffer.int16ChannelData?[0] else {
            throw DictationError.unsupportedFormat
        }
        return Data(bytes: pointer, count: byteCount)
    }

    private final class ConsumedFlag: @unchecked Sendable {
        var value = false
    }

    public static func int16Data(from samples: [Float]) -> Data {
        var ints = [Int16](repeating: 0, count: samples.count)
        for index in samples.indices {
            let clipped = max(-1, min(1, samples[index]))
            ints[index] = Int16((clipped * Float(Int16.max)).rounded())
        }
        return ints.withUnsafeBytes { Data($0) }
    }
}
