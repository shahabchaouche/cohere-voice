import Foundation

public actor DictationStore {
    private let fileURL: URL
    private var records: [DictationRecord] = []
    private var loaded = false

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func applicationSupportURL() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appending(path: "CohereVoice", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "history.json")
    }

    public func all() throws -> [DictationRecord] {
        try loadIfNeeded()
        return records
    }

    public func search(_ query: String) throws -> [DictationRecord] {
        try loadIfNeeded()
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return records }
        return records.filter {
            $0.rawTranscript.lowercased().contains(needle)
                || $0.processedTranscript.lowercased().contains(needle)
                || ($0.application?.lowercased().contains(needle) ?? false)
        }
    }

    public func add(_ record: DictationRecord) throws {
        try loadIfNeeded()
        records.insert(record, at: 0)
        try persist()
    }

    public func update(_ record: DictationRecord) throws {
        try loadIfNeeded()
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index] = record
        try persist()
    }

    public func clear() throws {
        records = []
        loaded = true
        try persist()
    }

    public func delete(id: UUID) throws {
        try loadIfNeeded()
        records.removeAll { $0.id == id }
        try persist()
    }

    private func loadIfNeeded() throws {
        guard !loaded else { return }
        loaded = true
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            records = []
            return
        }
        let data = try Data(contentsOf: fileURL)
        records = try JSONDecoder().decode([DictationRecord].self, from: data)
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(records)
        let temp = fileURL.appendingPathExtension("tmp")
        try data.write(to: temp, options: .atomic)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temp)
        } else {
            try FileManager.default.moveItem(at: temp, to: fileURL)
        }
    }
}
