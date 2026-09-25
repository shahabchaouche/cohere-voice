import SwiftUI
import UIKit
import CohereVoiceCore

@MainActor
@Observable
final class iOSSession {
    var apiKey: String = ""
    var keyLoaded = false
    var isRecording = false
    var status = "Loading saved key…"
    var raw = ""
    var processed = ""
    var error: String?

    private let pipeline = DefaultAudioPipeline()
    private let keychain = KeychainStore(service: "com.shahab.coherevoice.ios")
    private let metrics = MetricsCollector()

    func loadKey() async {
        defer {
            keyLoaded = true
            status = "Ready"
        }
        do {
            let storedKey = try await keychain.loadAPIKey() ?? ""
            if apiKey.isEmpty {
                apiKey = storedKey
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func saveKey() async {
        guard keyLoaded else { return }
        do {
            try await persistKey()
            error = nil
            status = "Key saved"
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func persistKey() async throws {
        try await keychain.saveAPIKey(apiKey)
    }

    func toggle() {
        if isRecording {
            Task { await stop() }
        } else {
            Task { await start() }
        }
    }

    private func start() async {
        guard keyLoaded else { return }
        error = nil
        do {
            try await persistKey()
            status = "Listening…"
            isRecording = true
            await metrics.reset()
            await metrics.mark(.shortcutDown)
            try await pipeline.start()
            await metrics.mark(.engineStarted)
        } catch {
            isRecording = false
            self.error = error.localizedDescription
            status = "Failed"
        }
    }

    private func stop() async {
        isRecording = false
        status = "Processing…"
        do {
            let recorded = try await pipeline.stop()
            await metrics.mark(.recordingStopped)
            guard !recorded.isTooShort else { throw DictationError.emptySpeech }
            await metrics.mark(.encodingCompleted)
            let client = APIClient(keyProvider: KeychainAPIKeyProvider(store: keychain))
            let transcriber = CohereTranscriptionService(client: client)
            await metrics.mark(.requestSent)
            let transcript = try await transcriber.transcribe(recorded)
            await metrics.mark(.transcriptionReturned)
            raw = transcript.text
            let processor = FallbackTranscriptProcessor(primary: CohereTranscriptProcessor(client: client))
            let result = try await processor.process(
                transcript: transcript,
                context: DictationContext(mode: .standard)
            )
            await metrics.mark(.rewriteReturned)
            processed = result.text
            status = result.usedFallback ? "Done — raw transcript" : "Done"
            error = result.usedFallback ? "Rewrite failed; the raw transcript is shown below." : nil
        } catch let error as DictationError {
            self.error = error.userMessage
            status = "Failed"
        } catch {
            self.error = error.localizedDescription
            status = "Failed"
        }
    }
}

struct iOSRootView: View {
    @State private var session = iOSSession()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Cohere Voice")
                    .font(CVFont.windowTitle)
                    .foregroundStyle(CVColor.ink)

                section("Cohere API") {
                    GroupedCard {
                        SecureField("API key", text: $session.apiKey)
                            .font(CVFont.mono)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                        Hairline()
                        Button("Save key") { Task { await session.saveKey() } }
                            .font(CVFont.label)
                            .foregroundStyle(CVColor.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .buttonStyle(.plain)
                            .disabled(!session.keyLoaded)
                    }
                }

                section("Dictation") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(session.isRecording ? CVColor.live : (session.status == "Done" ? CVColor.success : CVColor.textTertiary))
                                .frame(width: 8, height: 8)
                            Text(session.status)
                                .font(CVFont.body)
                                .foregroundStyle(CVColor.ink)
                        }
                        Button(session.isRecording ? "Stop" : "Hold-style Record") {
                            session.toggle()
                        }
                        .buttonStyle(InkButtonStyle(kind: session.isRecording ? .live : .prominent))
                        .disabled(!session.keyLoaded)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CVColor.surface, in: RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous)
                            .stroke(CVColor.border, lineWidth: 1)
                    )
                }

                if !session.raw.isEmpty {
                    section("Raw") {
                        Text(session.raw)
                            .font(CVFont.body)
                            .foregroundStyle(CVColor.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(CVColor.surface, in: RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous)
                                    .stroke(CVColor.border, lineWidth: 1)
                            )
                    }
                }

                if !session.processed.isEmpty {
                    section("Processed") {
                        GroupedCard {
                            Text(session.processed)
                                .font(CVFont.body)
                                .foregroundStyle(CVColor.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                            Hairline()
                            ShareLink(item: session.processed) {
                                Text("Share")
                                    .font(CVFont.label)
                                    .foregroundStyle(CVColor.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .frame(height: 44)
                            }
                            .buttonStyle(.plain)
                            Hairline()
                            Button("Copy") {
                                UIPasteboard.general.string = session.processed
                            }
                            .font(CVFont.label)
                            .foregroundStyle(CVColor.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let error = session.error {
                    section("Error") {
                        Text(error)
                            .font(CVFont.secondary)
                            .foregroundStyle(CVColor.warning)
                    }
                }

                Text("Recording stays in this app. Copy or share the text when you are done.")
                    .font(CVFont.caption)
                    .foregroundStyle(CVColor.textTertiary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(CVColor.canvas)
        .tint(CVColor.ink)
        .task { await session.loadKey() }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(CVFont.caption)
                .foregroundStyle(CVColor.textTertiary)
            content()
        }
    }
}
