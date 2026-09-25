import SwiftUI
import CohereVoiceCore

struct FloatingRecorderView: View {
    var state: DictationState
    var message: String
    var levels: [Float]

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .background {
                    if state == .recording {
                        Circle()
                            .fill(CVColor.live.opacity(0.25))
                            .frame(width: 16, height: 16)
                    }
                }

            if state == .recording {
                WaveformView(levels: levels, isRecording: true)
            }

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.15), value: message)
        }
        .padding(.horizontal, 16)
        .frame(width: 320, height: 52, alignment: .leading)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(CVColor.hud.opacity(0.92)))
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .clipShape(Capsule())
    }

    private var dotColor: Color {
        switch state {
        case .recording: CVColor.live
        case .failed: CVColor.warning
        case .completed: CVColor.success
        default: Color.white.opacity(0.55)
        }
    }
}
