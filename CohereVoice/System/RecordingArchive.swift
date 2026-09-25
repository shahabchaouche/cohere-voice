import Foundation

enum RecordingArchive {
    static func save(_ wav: Data) throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appending(path: "CohereVoice/recordings", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(ISO8601DateFormatter().string(from: Date())).wav")
        try wav.write(to: url)
        return url
    }
}
