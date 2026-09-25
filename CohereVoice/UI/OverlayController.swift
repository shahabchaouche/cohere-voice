import AppKit
import SwiftUI
import CohereVoiceCore

@MainActor
final class OverlayController {
    private var panel: OverlayPanel?
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
    }

    func show(message: String) {
        model.overlayMessage = message
        model.overlayVisible = true
        if panel == nil {
            panel = makePanel()
        }
        position(panel)
        panel?.orderFrontRegardless()
    }

    func hide() {
        model.overlayVisible = false
        panel?.orderOut(nil)
    }

    private func makePanel() -> OverlayPanel {
        let panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 52),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        let view = FloatingRecorderHost(model: model)
        panel.contentView = NSHostingView(rootView: view)
        return panel
    }

    private func position(_ panel: OverlayPanel?) {
        guard let panel, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.minY + 72
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private struct FloatingRecorderHost: View {
    @Bindable var model: AppModel

    var body: some View {
        FloatingRecorderView(
            state: model.state,
            message: model.overlayMessage,
            levels: model.levels
        )
    }
}
