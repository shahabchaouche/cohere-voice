import Foundation
import CohereVoiceCore

@MainActor
final class DictationHistoryController {
    let model: AppModel
    let settings: AppSettings
    let store: DictationStore
    let keychain: KeychainStore

    init(model: AppModel, settings: AppSettings, store: DictationStore, keychain: KeychainStore) {
        self.model = model
        self.settings = settings
        self.store = store
        self.keychain = keychain
    }

    func reload() async {
        model.history = (try? await store.all()) ?? []
    }

    func clear() {
        Task {
            try? await store.clear()
            await reload()
        }
    }

    func record(
        raw: String,
        processed: String,
        application: String?,
        latency: DictationLatency,
        usedFallback: Bool
    ) async {
        guard settings.historyEnabled else { return }
        let record = DictationRecord(
            rawTranscript: raw,
            processedTranscript: processed,
            application: application,
            mode: settings.mode,
            latency: latency,
            usedRewriteFallback: usedFallback
        )
        try? await store.add(record)
        await reload()
    }

    func delete(_ record: DictationRecord) {
        let id = record.id
        Task {
            try? await store.delete(id: id)
            await reload()
        }
    }

    func reprocess(_ record: DictationRecord) {
        Task {
            do {
                let client = APIClient(keyProvider: KeychainAPIKeyProvider(store: keychain))
                let processor = FallbackTranscriptProcessor(primary: CohereTranscriptProcessor(client: client))
                let context = DictationContext(
                    applicationName: record.application,
                    mode: record.mode,
                    dictionaryTerms: settings.dictionaryTerms,
                    language: settings.language.rawValue
                )
                let processed = try await processor.process(
                    transcript: Transcript(text: record.rawTranscript),
                    context: context
                )
                var updated = record
                updated.processedTranscript = processed.text
                updated.usedRewriteFallback = processed.usedFallback
                try await store.update(updated)
                await reload()
            } catch {
                model.lastError = error.localizedDescription
            }
        }
    }
}
