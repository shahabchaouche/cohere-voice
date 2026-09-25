import SwiftUI
import CohereVoiceCore

struct LatencyPanelView: View {
    @Environment(AppCoordinator.self) private var coordinator

    private var isRecording: Bool { coordinator.model.state == .recording }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Latency")
                    .font(CVFont.windowTitle)
                    .foregroundStyle(CVColor.ink)
                Spacer()
                Button(isRecording ? "Stop" : "Record") {
                    coordinator.dictation.debugRecordToggle()
                }
                .buttonStyle(SecondaryButtonStyle())
                .focusable(false)
                .focusEffectDisabled()
            }

            if !coordinator.model.lastRawTranscript.isEmpty {
                TranscriptBox(title: "Raw", text: coordinator.model.lastRawTranscript)
            }
            if coordinator.settings.rewriteEnabled, !coordinator.model.lastTranscript.isEmpty {
                TranscriptBox(title: "Processed", text: coordinator.model.lastTranscript)
            }
            if let error = coordinator.model.lastError {
                Text(error)
                    .font(CVFont.secondary)
                    .foregroundStyle(CVColor.warning)
            }

            GroupedCard {
                ForEach(Array(rows.enumerated()), id: \.element.label) { index, row in
                    let isTotal = index == rows.count - 1
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
                    .padding(.horizontal, 16)
                    .frame(height: isTotal ? 44 : 40)
                    .background(isTotal ? CVColor.canvas : CVColor.surface)
                    if index < rows.count - 1 {
                        Hairline()
                    }
                }
            }
        }
        }
        .padding(24)
        .frame(width: 480, height: 420)
        .background(CVColor.surface)
        .tint(CVColor.ink)
    }

    private var rows: [(label: String, milliseconds: Double?)] {
        coordinator.model.lastLatency?.rows ?? DictationLatency().rows
    }
}
