import Foundation

struct Latency: Codable {
    var recordingStartupMs: Double?
    var encodingMs: Double?
    var transcriptionMs: Double?
    var rewriteMs: Double?
    var insertionMs: Double?
    var totalPostRecordingMs: Double?
}

struct Record: Codable {
    var createdAt: Date
    var latency: Latency
}

func median(_ values: [Double]) -> Double? {
    let sorted = values.sorted()
    guard !sorted.isEmpty else { return nil }
    let mid = sorted.count / 2
    if sorted.count.isMultiple(of: 2) {
        return (sorted[mid - 1] + sorted[mid]) / 2
    }
    return sorted[mid]
}

func format(_ value: Double?) -> String {
    guard let value else { return "—" }
    return "\(Int(value.rounded())) ms"
}

let limit = CommandLine.arguments.dropFirst().first.flatMap(Int.init) ?? 15
let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
let url = root.appending(path: "CohereVoice/history.json")
guard FileManager.default.fileExists(atPath: url.path) else {
    fputs("No history at \(url.path)\n", stderr)
    exit(1)
}

let data = try Data(contentsOf: url)
let records = try JSONDecoder().decode([Record].self, from: data)
let slice = Array(records.prefix(limit))
guard !slice.isEmpty else {
    fputs("History is empty.\n", stderr)
    exit(1)
}

let columns: [(String, (Latency) -> Double?)] = [
    ("Recording startup", \.recordingStartupMs),
    ("Audio encoding", \.encodingMs),
    ("Transcription", \.transcriptionMs),
    ("Rewrite", \.rewriteMs),
    ("Insertion", \.insertionMs),
    ("Total after release", \.totalPostRecordingMs),
]

print("| Stage | Median |")
print("| --- | --- |")
for (label, keyPath) in columns {
    let values = slice.compactMap { keyPath($0.latency) }
    print("| \(label) | \(format(median(values))) |")
}

let newest = slice.map(\.createdAt).max() ?? Date()
let formatter = ISO8601DateFormatter()
print()
print("Count: \(slice.count)")
print("Newest: \(formatter.string(from: newest))")
