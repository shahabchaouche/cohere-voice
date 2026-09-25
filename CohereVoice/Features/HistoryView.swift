import AppKit
import SwiftUI
import CohereVoiceCore

struct HistoryView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var query = ""
    @State private var selection: DictationRecord.ID?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detailPane
        }
        .frame(minWidth: 760, minHeight: 480)
        .background(CVColor.surface)
        .tint(CVColor.ink)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .font(CVFont.secondary)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(CVColor.surface, in: RoundedRectangle(cornerRadius: CVRadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CVRadius.control, style: .continuous)
                        .stroke(CVColor.border, lineWidth: 1)
                )

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filtered) { record in
                        Button {
                            selection = record.id
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.processedTranscript)
                                    .font(.system(size: 14, weight: selection == record.id ? .medium : .regular))
                                    .foregroundStyle(CVColor.ink)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text(meta(record))
                                    .font(CVFont.caption)
                                    .foregroundStyle(CVColor.textTertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                selection == record.id ? CVColor.surface : Color.clear,
                                in: RoundedRectangle(cornerRadius: CVRadius.control, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 280)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(CVColor.canvas)
    }

    private var detailPane: some View {
        Group {
            if let record = filtered.first(where: { $0.id == selection }) {
                detail(record)
            } else {
                Text("Select a dictation")
                    .font(CVFont.body)
                    .foregroundStyle(CVColor.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CVColor.surface)
    }

    private var filtered: [DictationRecord] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return coordinator.model.history }
        return coordinator.model.history.filter {
            $0.rawTranscript.lowercased().contains(needle)
                || $0.processedTranscript.lowercased().contains(needle)
                || ($0.application?.lowercased().contains(needle) ?? false)
        }
    }

    private func meta(_ record: DictationRecord) -> String {
        let app = record.application ?? "Unknown app"
        let when = record.createdAt.formatted(date: .abbreviated, time: .shortened)
        return "\(app) · \(when) · \(record.mode.displayName)"
    }

    private func detail(_ record: DictationRecord) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if record.rawTranscript == record.processedTranscript {
                    TranscriptBox(title: "Transcript", text: record.rawTranscript)
                } else {
                    TranscriptBox(title: "Processed", text: record.processedTranscript)
                    TranscriptBox(title: "Raw", text: record.rawTranscript)
                }

                HStack(spacing: 24) {
                    metaColumn("App", record.application ?? "—")
                    metaColumn("Mode", record.mode.displayName)
                }

                if record.usedRewriteFallback {
                    Text("Rewrite fell back to the raw transcript.")
                        .font(CVFont.secondary)
                        .foregroundStyle(CVColor.warning)
                }

                latency(record.latency)

                HStack(spacing: 8) {
                    Button("Copy processed") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(record.processedTranscript, forType: .string)
                    }
                    .buttonStyle(InkButtonStyle())
                    Button("Copy raw") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(record.rawTranscript, forType: .string)
                    }
                    .buttonStyle(TintedButtonStyle())
                    Button("Re-process") {
                        coordinator.history.reprocess(record)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Button("Delete") {
                        coordinator.history.delete(record)
                        if selection == record.id {
                            selection = nil
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metaColumn(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(CVFont.caption)
                .foregroundStyle(CVColor.textTertiary)
            Text(value)
                .font(CVFont.label)
                .foregroundStyle(CVColor.ink)
        }
    }

    private func latency(_ latency: DictationLatency) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latency")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CVColor.ink)
            ForEach(Array(latency.rows.enumerated()), id: \.element.label) { index, row in
                let isTotal = index == latency.rows.count - 1
                HStack {
                    Text(row.label)
                        .font(isTotal ? CVFont.label : CVFont.secondary)
                        .foregroundStyle(isTotal ? CVColor.ink : CVColor.textSecondary)
                    Spacer()
                    Text(DictationLatency.format(row.milliseconds))
                        .font(CVFont.mono)
                        .monospacedDigit()
                        .foregroundStyle(CVColor.ink)
                }
            }
        }
    }
}
