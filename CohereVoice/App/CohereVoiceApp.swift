import AppKit
import SwiftUI

@main
struct CohereVoiceApp: App {
    @NSApplicationDelegateAdaptor(CohereAppDelegate.self) private var appDelegate
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        Window("Cohere Voice", id: "main") {
            MainView()
                .environment(coordinator)
                .windowSized()
        }
        .defaultSize(width: 560, height: 480)
        .windowResizability(.contentMinSize)

        Window("Settings", id: "settings") {
            SettingsView()
                .environment(coordinator)
                .windowSized()
        }
        .defaultSize(width: 560, height: 480)
        .windowResizability(.contentSize)

        Window("History", id: "history") {
            HistoryView()
                .environment(coordinator)
                .windowSized()
        }
        .defaultSize(width: 860, height: 560)
        .windowResizability(.contentMinSize)

        Window("Onboarding", id: "onboarding") {
            OnboardingView()
                .environment(coordinator)
                .windowSized()
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 620, height: 520)
        .windowResizability(.contentSize)

        Window("Latency", id: "latency") {
            LatencyPanelView()
                .environment(coordinator)
                .windowSized()
        }
        .defaultSize(width: 480, height: 420)
        .windowResizability(.contentSize)
    }
}

private struct WindowSized: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { Self.lock(view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { Self.lock(nsView) }
    }

    private static func lock(_ view: NSView) {
        guard let window = view.window else { return }
        window.styleMask.remove(.fullScreen)
        window.collectionBehavior.remove(.fullScreenPrimary)
        window.collectionBehavior.remove(.fullScreenAuxiliary)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.makeFirstResponder(nil)
        clearFocusRings(in: window.contentView)
    }

    private static func clearFocusRings(in view: NSView?) {
        guard let view else { return }
        view.focusRingType = .none
        (view as? NSControl)?.focusRingType = .none
        view.subviews.forEach { clearFocusRings(in: $0) }
    }
}

private extension View {
    func windowSized() -> some View {
        background(WindowSized())
    }
}

final class CohereAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}
