import AppKit

struct FocusedApplication: Sendable, Equatable {
    var bundleIdentifier: String?
    var name: String
}

@MainActor
final class ActiveApplicationService {
    func frontmost() -> FocusedApplication {
        let app = NSWorkspace.shared.frontmostApplication
        return FocusedApplication(
            bundleIdentifier: app?.bundleIdentifier,
            name: app?.localizedName ?? "Unknown"
        )
    }
}
