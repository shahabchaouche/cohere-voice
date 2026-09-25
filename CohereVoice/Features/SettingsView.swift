import SwiftUI
import CohereVoiceCore

struct SettingsView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var apiKey: String = ""
    @State private var keySaved = false
    @State private var keyActionBusy = false
    @State private var keyMessage: String?
    @State private var dictionaryDraft = ""
    @State private var tab: SettingsTab = .general

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsTabs
            ScrollView {
                Group {
                    switch tab {
                    case .general:
                        generalTab
                    case .api:
                        apiTab
                    case .dictionary:
                        dictionaryTab
                    case .privacy:
                        privacyTab
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
            }
        }
        .padding(24)
        .frame(width: 560, height: 480)
        .background(CVColor.surface)
        .tint(CVColor.ink)
        .task {
            let storedKey = await coordinator.refreshAPIKey()
            if apiKey.isEmpty {
                apiKey = storedKey ?? ""
            }
            dictionaryDraft = coordinator.settings.dictionaryTerms.joined(separator: "\n")
        }
    }

    private var settingsTabs: some View {
        HStack(spacing: 2) {
            ForEach(SettingsTab.allCases) { item in
                Button(item.title) { tab = item }
                    .font(CVFont.label)
                    .foregroundStyle(tab == item ? CVColor.ink : CVColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .focusEffectDisabled()
                    .background {
                        if tab == item {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(CVColor.surface)
                                .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                        }
                    }
                    .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(CVColor.sunken, in: RoundedRectangle(cornerRadius: CVRadius.control, style: .continuous))
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupedCard {
                settingsMenu("Shortcut", value: coordinator.settings.hotkey.displayName, monospaced: true) {
                    ForEach(HotkeyOption.allCases) { option in
                        Button(option.displayName) {
                            coordinator.settings.hotkey = option
                            coordinator.applyHotkey(option)
                        }
                    }
                }
                Hairline()
                settingsMenu("Mode", value: coordinator.settings.mode.displayName) {
                    ForEach(DictationMode.allCases) { mode in
                        Button(mode.displayName) {
                            coordinator.settings.mode = mode
                        }
                    }
                }
                Hairline()
                settingsMenu("Transcription language", value: coordinator.settings.language.displayName) {
                    ForEach(TranscriptionLanguage.allCases) { language in
                        Button(language.displayName) {
                            coordinator.settings.language = language
                        }
                    }
                }
                Hairline()
                Toggle("Clean up transcript", isOn: Bindable(coordinator.settings).rewriteEnabled)
                    .toggleStyle(InkToggleStyle())
                    .font(CVFont.row)
                    .foregroundStyle(CVColor.ink)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
            }

            if coordinator.settings.hotkey.requiresFnHint {
                Text("Set System Settings → Keyboard → “Press 🌐 key to” to Do Nothing, or Fn will open system Dictation.")
                    .font(CVFont.secondary)
                    .foregroundStyle(CVColor.textSecondary)
            }

            Text("Microphone audio is sent to Cohere for transcription. When cleanup is on, the transcript is sent to Cohere again for rewriting.")
                .font(CVFont.caption)
                .foregroundStyle(CVColor.textTertiary)
            Text("Turn cleanup off to insert the transcript as dictated, without a rewrite.")
                .font(CVFont.caption)
                .foregroundStyle(CVColor.textTertiary)
        }
    }

    private var apiTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Cohere API key")
                    .font(CVFont.label)
                    .foregroundStyle(CVColor.ink)
                SecureField("Cohere API key", text: $apiKey)
                    .font(CVFont.mono)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(CVColor.surface, in: RoundedRectangle(cornerRadius: CVRadius.control, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CVRadius.control, style: .continuous)
                            .stroke(CVColor.border, lineWidth: 1)
                    )
            }

            HStack(spacing: 12) {
                Button("Save to Keychain") {
                    saveKey()
                }
                .buttonStyle(InkButtonStyle())
                .disabled(keyActionBusy || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if keySaved {
                    Text("Saved")
                        .font(CVFont.label)
                        .foregroundStyle(CVColor.success)
                }
            }

            if coordinator.model.apiKeyStatus == .repairRequired {
                Button("Repair Access") {
                    repairAccess()
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(keyActionBusy)
            }

            if let keyMessage {
                Text(keyMessage)
                    .font(CVFont.secondary)
                    .foregroundStyle(CVColor.warning)
            }

            Button("Remove key") {
                removeKey()
            }
            .buttonStyle(GhostButtonStyle())
            .disabled(keyActionBusy)

            Text("The key is stored in the macOS Keychain. It is never written to UserDefaults or the git repository.")
                .font(CVFont.caption)
                .foregroundStyle(CVColor.textTertiary)
        }
    }

    private func saveKey() {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        keyActionBusy = true
        keySaved = false
        keyMessage = nil
        Task {
            defer { keyActionBusy = false }
            do {
                try await coordinator.keychain.saveAPIKey(key)
                _ = await coordinator.refreshAPIKey()
                if coordinator.model.apiKeyStatus == .available {
                    keySaved = true
                } else {
                    keyMessage = "The key was saved, but routine access still needs repair."
                }
            } catch {
                _ = await coordinator.refreshAPIKey()
                keyMessage = error.localizedDescription
            }
        }
    }

    private func repairAccess() {
        keyActionBusy = true
        keySaved = false
        keyMessage = nil
        Task {
            defer { keyActionBusy = false }
            do {
                let repairedKey = try await coordinator.keychain.repairAPIKeyAccess()
                let verifiedKey = await coordinator.refreshAPIKey()
                if coordinator.model.apiKeyStatus == .available, let verifiedKey {
                    apiKey = verifiedKey
                    keyMessage = "Access repaired."
                } else {
                    apiKey = repairedKey ?? apiKey
                    keyMessage = "Authorization did not persist. Try saving the key here. If the old item blocks saving, remove it in Keychain Access first."
                }
            } catch {
                _ = await coordinator.refreshAPIKey()
                keyMessage = error.localizedDescription
            }
        }
    }

    private func removeKey() {
        keyActionBusy = true
        keySaved = false
        keyMessage = nil
        Task {
            defer { keyActionBusy = false }
            do {
                try await coordinator.keychain.deleteAPIKey()
                apiKey = ""
                _ = await coordinator.refreshAPIKey()
            } catch {
                _ = await coordinator.refreshAPIKey()
                keyMessage = error.localizedDescription
            }
        }
    }

    private var dictionaryTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Personal dictionary")
                    .font(CVFont.section)
                    .foregroundStyle(CVColor.ink)
                Text("One term per line. These words are sent with each rewrite prompt.")
                    .font(CVFont.secondary)
                    .foregroundStyle(CVColor.textSecondary)
            }

            TextEditor(text: $dictionaryDraft)
                .font(CVFont.mono)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 160)
                .background(CVColor.surface, in: RoundedRectangle(cornerRadius: CVRadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CVRadius.control, style: .continuous)
                        .stroke(CVColor.border, lineWidth: 1)
                )

            Button("Save dictionary") {
                coordinator.settings.dictionaryTerms = dictionaryDraft
                    .split(whereSeparator: \.isNewline)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
            .buttonStyle(InkButtonStyle())
        }
    }

    private var privacyTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupedCard {
                Toggle("Keep local history", isOn: Bindable(coordinator.settings).historyEnabled)
                    .toggleStyle(InkToggleStyle())
                    .font(CVFont.row)
                    .foregroundStyle(CVColor.ink)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                Hairline()
                Toggle("Save WAV recordings (developer)", isOn: Bindable(coordinator.settings).saveRecordings)
                    .toggleStyle(InkToggleStyle())
                    .font(CVFont.row)
                    .foregroundStyle(CVColor.ink)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                Hairline()
                Toggle("Include selected text in rewrites", isOn: Bindable(coordinator.settings).includeSelectedTextInRewrite)
                    .toggleStyle(InkToggleStyle())
                    .font(CVFont.row)
                    .foregroundStyle(CVColor.ink)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
            }

            Text("When cleanup is on, Cohere receives the transcript, active app name, and saved dictionary terms. If selected-text context is enabled, up to 400 selected characters from the active app are also sent. This setting is off by default.")
                .font(CVFont.caption)
                .foregroundStyle(CVColor.textTertiary)

            Text("Local text history is on by default. WAV recordings are off by default; audio is saved only when you enable that toggle.")
                .font(CVFont.caption)
                .foregroundStyle(CVColor.textTertiary)

            Button("Clear history") {
                coordinator.history.clear()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private func settingsMenu<Items: View>(_ title: String, value: String, monospaced: Bool = false, @ViewBuilder menu: () -> Items) -> some View {
        HStack {
            Text(title)
                .font(CVFont.row)
                .foregroundStyle(CVColor.ink)
            Spacer()
            Menu {
                menu()
            } label: {
                Text(value)
                    .font(monospaced ? CVFont.mono : CVFont.label)
                    .foregroundStyle(CVColor.textSecondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.visible)
            .fixedSize()
            .focusEffectDisabled()
            .modifier(MacFocusRing())
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }
}

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case api
    case dictionary
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .api: "API"
        case .dictionary: "Dictionary"
        case .privacy: "Privacy"
        }
    }
}
