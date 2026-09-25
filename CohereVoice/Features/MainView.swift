import AppKit
import SwiftUI
import CohereVoiceCore

struct MainView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.openWindow) private var openWindow

    private var isRecording: Bool { coordinator.model.state == .recording }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Cohere Voice")
                    .font(CVFont.windowTitle)
                    .foregroundStyle(CVColor.ink)
                Spacer()
                StatusChip(title: "Mic", granted: coordinator.microphoneGranted)
                StatusChip(title: "Accessibility", granted: coordinator.accessibilityGranted)
            }

            HStack {
                menuField("Transcribe", value: coordinator.settings.language.displayName) {
                    ForEach(TranscriptionLanguage.allCases) { language in
                        Button(language.displayName) {
                            coordinator.settings.language = language
                        }
                    }
                }

                Spacer()

                menuField("Shortcut", value: coordinator.settings.hotkey.displayName) {
                    ForEach(HotkeyOption.allCases) { option in
                        Button(option.displayName) {
                            coordinator.settings.hotkey = option
                            coordinator.applyHotkey(option)
                        }
                    }
                }
            }

            Text(statusLine)
                .font(CVFont.body)
                .foregroundStyle(CVColor.textSecondary)

            if let message = coordinator.shortcutHint {
                Text(message)
                    .font(CVFont.secondary)
                    .foregroundStyle(CVColor.warning)
            }

            Button {
                coordinator.dictation.debugRecordToggle()
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(CVColor.live)
                        .frame(width: 8, height: 8)
                    Text(isRecording ? "Stop recording" : "Record")
                }
            }
            .buttonStyle(InkButtonStyle(kind: isRecording ? .live : .prominent))
            .focusEffectDisabled()
            .disabled(!coordinator.microphoneGranted || !coordinator.model.hasAPIKey)

            Toggle("Clean up transcript", isOn: Bindable(coordinator.settings).rewriteEnabled)
                .toggleStyle(InkToggleStyle())
                .font(CVFont.row)
                .foregroundStyle(CVColor.ink)

            if let keyMessage {
                Text(keyMessage)
                    .font(CVFont.secondary)
                    .foregroundStyle(CVColor.warning)
            }

            if !coordinator.accessibilityGranted {
                Text("Accessibility is off, so text cannot be inserted into other apps yet. Open Onboarding to enable it.")
                    .font(CVFont.secondary)
                    .foregroundStyle(CVColor.textSecondary)
            }

            if let error = coordinator.model.lastError {
                Text(error)
                    .font(CVFont.secondary)
                    .foregroundStyle(CVColor.warning)
            }

            if !coordinator.model.lastRawTranscript.isEmpty {
                TranscriptBox(title: "Raw", text: coordinator.model.lastRawTranscript)
            }
            if coordinator.settings.rewriteEnabled, !coordinator.model.lastTranscript.isEmpty {
                TranscriptBox(title: "Processed", text: coordinator.model.lastTranscript)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                footerLink("Onboarding") { openWindow(id: "onboarding") }
                footerLink("Settings") { openWindow(id: "settings") }
                footerLink("History") { openWindow(id: "history") }
                footerLink("Latency") { openWindow(id: "latency") }
            }
            .padding(.top, 4)
            .overlay(alignment: .top) { Hairline() }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 420, alignment: .topLeading)
        .background(CVColor.surface)
        .tint(CVColor.ink)
        .onAppear {
            coordinator.start()
            coordinator.permissions.refresh()
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
            if !coordinator.settings.hasCompletedOnboarding && !coordinator.microphoneGranted {
                openWindow(id: "onboarding")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            coordinator.permissions.refresh()
        }
    }

    private var statusLine: String {
        if coordinator.model.state != .idle {
            return coordinator.model.state.overlayTitle
        }
        if !coordinator.microphoneGranted {
            return "Allow the microphone in Onboarding, then hold the shortcut or press Record."
        }
        let shortcut = coordinator.settings.hotkey.displayName
        return "Hold \(shortcut) in any app, speak, release. Record still works here."
    }

    private var keyMessage: String? {
        switch coordinator.model.apiKeyStatus {
        case .checking, .available:
            nil
        case .missing:
            "API key is missing. Open Settings to add it."
        case .repairRequired:
            "The saved API key needs authorization. Open Settings and choose Repair Access."
        case .unavailable:
            "Could not read the saved API key. Open Settings and try again."
        }
    }

    private func footerLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(GhostButtonStyle())
            .focusEffectDisabled()
    }

    private func menuField<Items: View>(_ title: String, value: String, @ViewBuilder menu: () -> Items) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(CVFont.secondary)
                .foregroundStyle(CVColor.textTertiary)
            Menu {
                menu()
            } label: {
                Text(value)
                    .font(CVFont.label)
                    .foregroundStyle(CVColor.ink)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.visible)
            .fixedSize()
            .focusEffectDisabled()
            .modifier(MacFocusRing())
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(CVColor.surface, in: RoundedRectangle(cornerRadius: CVRadius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CVRadius.control, style: .continuous)
                .stroke(CVColor.border, lineWidth: 1)
        )
    }
}
