import Foundation
import Observation
import CohereVoiceCore

enum APIKeyStatus: Equatable {
    case checking
    case available
    case missing
    case repairRequired
    case unavailable
}

@MainActor
@Observable
final class AppModel {
    var state: DictationState = .idle
    var levels: [Float] = Array(repeating: 0, count: 24)
    var lastTranscript: String = ""
    var lastRawTranscript: String = ""
    var lastError: String?
    var lastLatency: DictationLatency?
    var history: [DictationRecord] = []
    var overlayVisible = false
    var overlayMessage = "Listening…"
    var apiKeyStatus: APIKeyStatus = .checking
    var hasAPIKey: Bool { apiKeyStatus == .available }

    func pushLevel(_ value: Float) {
        levels.removeFirst()
        levels.append(value)
    }

    func resetLevels() {
        levels = Array(repeating: 0, count: 24)
    }
}
