import SwiftUI

struct WaveformView: View {
    var levels: [Float]
    var isRecording: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(isRecording ? Color.white.opacity(0.92) : Color.white.opacity(0.45))
                    .frame(width: 2, height: barHeight(level))
            }
        }
        .frame(height: 18)
        .animation(.easeOut(duration: 0.08), value: levels)
    }

    private func barHeight(_ level: Float) -> CGFloat {
        CGFloat(max(3, min(18, 3 + level * 15)))
    }
}
