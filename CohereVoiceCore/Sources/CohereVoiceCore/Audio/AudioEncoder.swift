import Foundation

public enum AudioEncoder {
    public static let targetSampleRate = 16_000

    public static func encodeWAV(int16MonoPCM: Data, sampleRate: Int = targetSampleRate) -> Data {
        let dataSize = UInt32(int16MonoPCM.count)
        let byteRate = UInt32(sampleRate * 2)
        var header = Data()
        header.reserveCapacity(44 + int16MonoPCM.count)
        header.append(ascii("RIFF"))
        header.append(le32(36 + dataSize))
        header.append(ascii("WAVE"))
        header.append(ascii("fmt "))
        header.append(le32(16))
        header.append(le16(1))
        header.append(le16(1))
        header.append(le32(UInt32(sampleRate)))
        header.append(le32(byteRate))
        header.append(le16(2))
        header.append(le16(16))
        header.append(ascii("data"))
        header.append(le32(dataSize))
        header.append(int16MonoPCM)
        return header
    }

    public static func encodeWAV(floatMono: [Float], sourceSampleRate: Double) throws -> Data {
        let pcm = try AudioResampler.resampleTo16kMonoInt16(
            samples: floatMono,
            sourceSampleRate: sourceSampleRate
        )
        return encodeWAV(int16MonoPCM: pcm)
    }

    public static func parseWAVHeader(_ data: Data) -> WAVHeader? {
        guard data.count >= 44 else { return nil }
        let riff = String(bytes: data[0..<4], encoding: .ascii)
        let wave = String(bytes: data[8..<12], encoding: .ascii)
        let audioFormat = read16(data, 20)
        let channels = read16(data, 22)
        let sampleRate = read32(data, 24)
        let bits = read16(data, 34)
        let dataSize = read32(data, 40)
        guard riff == "RIFF", wave == "WAVE" else { return nil }
        return WAVHeader(
            audioFormat: audioFormat,
            channels: channels,
            sampleRate: sampleRate,
            bitsPerSample: bits,
            dataSize: dataSize
        )
    }

    public struct WAVHeader: Equatable, Sendable {
        public var audioFormat: UInt16
        public var channels: UInt16
        public var sampleRate: UInt32
        public var bitsPerSample: UInt16
        public var dataSize: UInt32
    }

    private static func ascii(_ value: String) -> Data {
        Data(value.utf8)
    }

    private static func le16(_ value: UInt16) -> Data {
        var value = value.littleEndian
        return Data(bytes: &value, count: 2)
    }

    private static func le32(_ value: UInt32) -> Data {
        var value = value.littleEndian
        return Data(bytes: &value, count: 4)
    }

    private static func read16(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func read32(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }
}
