import AppKit
import Observation
import SwiftUI
import CohereVoiceCore

@MainActor
@Observable
final class AppCoordinator {
    let model: AppModel
    let settings: AppSettings
    let permissions: PermissionService
    var microphoneGranted = false
    var accessibilityGranted = false
    let shortcuts: GlobalShortcutService
    let dictation: DictationCoordinator
    let history: DictationHistoryController
    let overlay: OverlayController
    let keychain = KeychainStore()
    var shortcutHint: String?

    init() {
        let model = AppModel()
        let settings = AppSettings()
        let permissions = PermissionService()
        let overlay = OverlayController(model: model)
        let storeURL = (try? DictationStore.applicationSupportURL())
            ?? FileManager.default.temporaryDirectory.appending(path: "coherevoice-history.json")
        let history = DictationHistoryController(
            model: model,
            settings: settings,
            store: DictationStore(fileURL: storeURL),
            keychain: KeychainStore()
        )
        let dictation = DictationCoordinator(
            model: model,
            settings: settings,
            pipeline: DefaultAudioPipeline(),
            metrics: MetricsCollector(),
            history: history,
            overlay: overlay,
            permissions: permissions
        )
        self.model = model
        self.settings = settings
        self.permissions = permissions
        self.overlay = overlay
        self.history = history
        self.dictation = dictation
        self.shortcuts = GlobalShortcutService()
    }

    private var didStart = false

    func start() {
        guard !didStart else { return }
        didStart = true
        permissions.onUpdate = { [weak self] in
            self?.publishPermissions()
        }
        dictation.shortcuts = shortcuts
        permissions.startObserving()
        publishPermissions()
        if permissions.microphoneGranted {
            settings.hasCompletedOnboarding = true
        }
        shortcuts.hotkey = settings.hotkey
        shortcuts.onDown = { [weak self] in
            self?.dictation.handleKeyDown()
        }
        shortcuts.onUp = { [weak self] in
            self?.dictation.handleKeyUp()
        }
        shortcuts.onCancel = { [weak self] in
            self?.dictation.cancel()
        }
        dictation.start()
        Task {
            await refreshAPIKey()
            shortcuts.start()
            shortcutHint = shortcuts.registrationMessage
        }
        Task { await history.reload() }
    }

    private func publishPermissions() {
        microphoneGranted = permissions.microphoneGranted
        accessibilityGranted = permissions.accessibilityGranted
    }

    private var keyReadGeneration = 0

    @discardableResult
    func refreshAPIKey() async -> String? {
        keyReadGeneration &+= 1
        let generation = keyReadGeneration
        do {
            let key = try await keychain.loadAPIKey()
            if generation == keyReadGeneration {
                model.apiKeyStatus = key?.isEmpty == false ? .available : .missing
            }
            return key
        } catch KeychainStore.KeychainError.interactionRequired {
            guard generation == keyReadGeneration else { return nil }
            model.apiKeyStatus = .repairRequired
        } catch {
            guard generation == keyReadGeneration else { return nil }
            model.apiKeyStatus = .unavailable
        }
        return nil
    }

    func applyHotkey(_ option: HotkeyOption) {
        settings.hotkey = option
        shortcuts.hotkey = option
        shortcutHint = shortcuts.registrationMessage
    }
}
