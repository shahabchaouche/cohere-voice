import SwiftUI

struct OnboardingView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    private var appURL: URL { Bundle.main.bundleURL }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Set up Cohere Voice")
                    .font(CVFont.windowTitle)
                    .foregroundStyle(CVColor.ink)
                Text("Hold \(coordinator.settings.hotkey.displayName) in Notes, Slack, Mail, or Cursor. Speak, then release. Text inserts at the cursor. Record in this window still works.")
                    .font(CVFont.body)
                    .foregroundStyle(CVColor.textSecondary)
            }

            permissionRow(
                title: "Microphone",
                granted: coordinator.microphoneGranted,
                detail: "Required to record. Click Request, then Allow."
            ) {
                NSApp.activate(ignoringOtherApps: true)
                Task { _ = await coordinator.permissions.requestMicrophone() }
            } settings: {
                coordinator.permissions.openMicrophoneSettings()
            }

            permissionRow(
                title: "Accessibility",
                granted: coordinator.accessibilityGranted,
                detail: accessibilityDetail
            ) {
                coordinator.permissions.requestAccessibility()
            } settings: {
                coordinator.permissions.openAccessibilitySettings()
            }

            HStack {
                Button("Recheck permissions") {
                    coordinator.permissions.recheck()
                }
                .buttonStyle(GhostButtonStyle())
                .focusEffectDisabled()
                Spacer()
                Button("Continue") {
                    coordinator.settings.hasCompletedOnboarding = true
                    dismiss()
                }
                .buttonStyle(InkButtonStyle())
                .focusEffectDisabled()
                .disabled(!coordinator.microphoneGranted)
            }

            Text("Microphone audio is sent to Cohere for transcription.")
                .font(CVFont.caption)
                .foregroundStyle(CVColor.textTertiary)
        }
        .padding(28)
        .frame(width: 620, alignment: .topLeading)
        .background(CVColor.surface)
        .tint(CVColor.ink)
        .onAppear {
            coordinator.permissions.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            coordinator.permissions.refresh()
        }
    }

    private var accessibilityDetail: String {
        let applicationsHome = NSHomeDirectory() + "/Applications/"
        if appURL.path.hasPrefix("/Applications/") || appURL.path.hasPrefix(applicationsHome) {
            return "Required to insert text into other apps."
        }
        return "This build is not installed in Applications, so macOS will not list it under Accessibility. Run Scripts/run.sh to install it, then come back."
    }

    private func permissionRow(
        title: String,
        granted: Bool,
        detail: String,
        action: @escaping () -> Void,
        settings: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .stroke(granted ? CVColor.success : CVColor.textTertiary, lineWidth: 1.5)
                .frame(width: 18, height: 18)
                .overlay {
                    if granted {
                        Circle()
                            .fill(CVColor.success)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CVColor.ink)
                Text(detail)
                    .font(CVFont.secondary)
                    .foregroundStyle(CVColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button(granted ? "Granted" : "Request", action: action)
                .buttonStyle(SecondaryButtonStyle())
                .focusEffectDisabled()
                .disabled(granted)
            Button("Open Settings", action: settings)
                .buttonStyle(SecondaryButtonStyle())
                .focusEffectDisabled()
        }
        .padding(14)
        .background(CVColor.canvas, in: RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
    }
}
