import Testing
import Foundation
@testable import CohereVoiceCore

struct StoreTests {
    @Test func selectedTextContextDefaultsOffForExistingPreferences() throws {
        let encoded = try JSONEncoder().encode(AppPreferences.default)
        var oldValues = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        oldValues.removeValue(forKey: "includeSelectedTextInRewrite")
        let oldData = try JSONSerialization.data(withJSONObject: oldValues)

        let restored = try JSONDecoder().decode(AppPreferences.self, from: oldData)
        #expect(!restored.includeSelectedTextInRewrite)
        #expect(!restored.shouldCaptureSelectedText)
    }

    @Test func selectedTextContextRequiresOptInAndRewrite() throws {
        var preferences = AppPreferences.default
        #expect(!preferences.shouldCaptureSelectedText)
        preferences.includeSelectedTextInRewrite = true
        #expect(preferences.shouldCaptureSelectedText)
        preferences.rewriteEnabled = false
        #expect(!preferences.shouldCaptureSelectedText)
        let restored = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(preferences))
        #expect(restored.includeSelectedTextInRewrite)
        #expect(!restored.shouldCaptureSelectedText)
    }

    @Test func jsonRoundTrip() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "coherevoice-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = DictationStore(fileURL: url)
        let record = DictationRecord(
            rawTranscript: "hey sarah",
            processedTranscript: "Hey Sarah.",
            application: "Mail",
            mode: .standard,
            latency: DictationLatency(totalPostRecordingMs: 800)
        )
        try await store.add(record)
        let loaded = try await store.all()
        #expect(loaded.count == 1)
        #expect(loaded[0].processedTranscript == "Hey Sarah.")
        let found = try await store.search("sarah")
        #expect(found.count == 1)
        try await store.clear()
        #expect(try await store.all().isEmpty)
    }

    @Test func deleteRemovesOneRecord() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "coherevoice-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = DictationStore(fileURL: url)
        let first = DictationRecord(
            rawTranscript: "keep",
            processedTranscript: "Keep.",
            mode: .standard,
            latency: DictationLatency()
        )
        let second = DictationRecord(
            rawTranscript: "drop",
            processedTranscript: "Drop.",
            mode: .standard,
            latency: DictationLatency()
        )
        try await store.add(first)
        try await store.add(second)
        try await store.delete(id: second.id)
        let loaded = try await store.all()
        #expect(loaded.map(\.id) == [first.id])
    }

    @Test func updateRoundTrip() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "coherevoice-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = DictationStore(fileURL: url)
        let record = DictationRecord(
            rawTranscript: "hey",
            processedTranscript: "Hey.",
            application: "Notes",
            mode: .standard,
            latency: DictationLatency(totalPostRecordingMs: 100)
        )
        try await store.add(record)
        var updated = record
        updated.processedTranscript = "Updated."
        try await store.update(updated)
        let loaded = try await store.all()
        #expect(loaded.count == 1)
        #expect(loaded[0].processedTranscript == "Updated.")
    }

    @Test func decodesRecordThatStillHasUploadMs() throws {
        let json = """
        [
          {
            "id": "00000000-0000-0000-0000-000000000001",
            "createdAt": 0,
            "rawTranscript": "hey",
            "processedTranscript": "Hey.",
            "application": "Notes",
            "mode": "standard",
            "latency": {
              "uploadMs": 12,
              "totalPostRecordingMs": 800
            },
            "usedRewriteFallback": false
          }
        ]
        """
        let records = try JSONDecoder().decode([DictationRecord].self, from: Data(json.utf8))
        #expect(records.count == 1)
        #expect(records[0].processedTranscript == "Hey.")
        #expect(records[0].latency.totalPostRecordingMs == 800)
    }
}
