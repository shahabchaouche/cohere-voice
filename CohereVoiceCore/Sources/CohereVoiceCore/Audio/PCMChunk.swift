import AVFoundation

public struct PCMChunk: Sendable {
    public let samples: Data
    public let frameCount: Int
    public let sampleRate: Double
    public let channelCount: AVAudioChannelCount
    public let commonFormat: AVAudioCommonFormat
    public let rms: Float

    public var frameDuration: TimeInterval {
        guard sampleRate > 0 else { return 0 }
        return TimeInterval(frameCount) / sampleRate
    }

    public func floatMonoSamples() -> [Float] {
        let frames = frameCount
        guard frames > 0 else { return [] }
        switch commonFormat {
        case .pcmFormatFloat32:
            return samples.withUnsafeBytes { buffer in
                let pointer = buffer.bindMemory(to: Float.self)
                guard !pointer.isEmpty else { return [] }
                if channelCount <= 1 {
                    return Array(pointer.prefix(frames))
                }
                var mono = [Float](repeating: 0, count: frames)
                let channels = Int(channelCount)
                for frame in 0..<frames {
                    var sum: Float = 0
                    for channel in 0..<channels {
                        let index = frame * channels + channel
                        if index < pointer.count {
                            sum += pointer[index]
                        }
                    }
                    mono[frame] = sum / Float(channels)
                }
                return mono
            }
        case .pcmFormatInt16:
            return samples.withUnsafeBytes { buffer in
                let pointer = buffer.bindMemory(to: Int16.self)
                let channels = max(Int(channelCount), 1)
                var mono = [Float](repeating: 0, count: frames)
                for frame in 0..<frames {
                    var sum: Float = 0
                    for channel in 0..<channels {
                        let index = frame * channels + channel
                        if index < pointer.count {
                            sum += Float(pointer[index]) / Float(Int16.max)
                        }
                    }
                    mono[frame] = sum / Float(channels)
                }
                return mono
            }
        default:
            return []
        }
    }

    public static func copy(from buffer: AVAudioPCMBuffer) -> PCMChunk? {
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return nil }
        let format = buffer.format
        let channels = Int(format.channelCount)
        var rms: Float = 0

        switch format.commonFormat {
        case .pcmFormatFloat32:
            guard let channelData = buffer.floatChannelData else { return nil }
            var interleaved = [Float](repeating: 0, count: frames * channels)
            for frame in 0..<frames {
                var mixed: Float = 0
                for channel in 0..<channels {
                    let sample = channelData[channel][frame]
                    interleaved[frame * channels + channel] = sample
                    mixed += sample
                }
                let mono = mixed / Float(max(channels, 1))
                rms += mono * mono
            }
            rms = sqrt(rms / Float(frames))
            return PCMChunk(
                samples: interleaved.withUnsafeBytes { Data($0) },
                frameCount: frames,
                sampleRate: format.sampleRate,
                channelCount: format.channelCount,
                commonFormat: .pcmFormatFloat32,
                rms: rms
            )
        case .pcmFormatInt16:
            guard let channelData = buffer.int16ChannelData else { return nil }
            var interleaved = [Int16](repeating: 0, count: frames * channels)
            for frame in 0..<frames {
                var mixed: Float = 0
                for channel in 0..<channels {
                    let sample = channelData[channel][frame]
                    interleaved[frame * channels + channel] = sample
                    mixed += Float(sample) / Float(Int16.max)
                }
                let mono = mixed / Float(max(channels, 1))
                rms += mono * mono
            }
            rms = sqrt(rms / Float(frames))
            return PCMChunk(
                samples: interleaved.withUnsafeBytes { Data($0) },
                frameCount: frames,
                sampleRate: format.sampleRate,
                channelCount: format.channelCount,
                commonFormat: .pcmFormatInt16,
                rms: rms
            )
        default:
            return nil
        }
    }
}
