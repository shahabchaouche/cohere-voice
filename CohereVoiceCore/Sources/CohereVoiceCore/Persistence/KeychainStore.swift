import Foundation
import LocalAuthentication
import Security

public struct KeychainStore: Sendable {
    public let service: String
    public let account: String
    private let operations: any KeychainOperations

    public init(service: String = "com.shahab.coherevoice", account: String = "cohere-api-key") {
        self.init(service: service, account: account, operations: SystemKeychainOperations())
    }

    init(service: String, account: String, operations: any KeychainOperations) {
        self.service = service
        self.account = account
        self.operations = operations
    }

    /// Routine reads never ask macOS to display authentication UI.
    public func loadAPIKey() async throws -> String? {
        try await Task.detached(priority: .userInitiated) {
            try readAPIKey(allowInteraction: false)
        }.value
    }

    /// Call only after a person chooses Repair Access in a visible settings window.
    public func repairAPIKeyAccess() async throws -> String? {
        try await Task.detached(priority: .userInitiated) {
            try readAPIKey(allowInteraction: true)
        }.value
    }

    public func saveAPIKey(_ key: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            try save(key)
        }.value
    }

    public func deleteAPIKey() async throws {
        try await Task.detached(priority: .userInitiated) {
            try delete()
        }.value
    }

    public enum KeychainError: Error, Sendable, Equatable, LocalizedError {
        case interactionRequired
        case invalidData
        case unhandled(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .interactionRequired:
                "The saved API key needs authorization. Open Settings and choose Repair Access."
            case .invalidData:
                "The saved API key could not be read. Enter it again in Settings."
            case .unhandled:
                "Keychain could not access the API key. Try again in Settings."
            }
        }
    }

    private func readAPIKey(allowInteraction: Bool) throws -> String? {
        let context = LAContext()
        context.interactionNotAllowed = !allowInteraction
        var query = identityQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context
        // Legacy macOS login-keychain ACLs can still show UI; keep the explicit
        // Security policy alongside LAContext for those existing items.
        query[kSecUseAuthenticationUI as String] = allowInteraction
            ? kSecUseAuthenticationUIAllow
            : kSecUseAuthenticationUIFail
        var item: CFTypeRef?
        let status = operations.copyMatching(query as CFDictionary, result: &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let key = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return key
        case errSecItemNotFound:
            return nil
        default:
            throw Self.error(for: status)
        }
    }

    private func save(_ key: String) throws {
        let data = Data(key.utf8)
        let context = LAContext()
        context.interactionNotAllowed = true
        var query = identityQuery()
        query[kSecUseAuthenticationContext as String] = context
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = operations.update(query as CFDictionary, attributes: update as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw Self.error(for: updateStatus) }

        var addition = identityQuery()
        addition[kSecValueData as String] = data
        addition[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        addition[kSecAttrLabel as String] = "Cohere API key"
        let addStatus = operations.add(addition as CFDictionary)
        if addStatus == errSecSuccess { return }
        if addStatus == errSecDuplicateItem {
            // Another save created the item between the update and add.
            let retryStatus = operations.update(query as CFDictionary, attributes: update as CFDictionary)
            if retryStatus == errSecSuccess { return }
            throw Self.error(for: retryStatus)
        }
        throw Self.error(for: addStatus)
    }

    private func delete() throws {
        let context = LAContext()
        context.interactionNotAllowed = true
        var query = identityQuery()
        query[kSecUseAuthenticationContext as String] = context
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        let status = operations.delete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Self.error(for: status)
        }
    }

    private func identityQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func error(for status: OSStatus) -> KeychainError {
        switch status {
        case errSecInteractionNotAllowed, errSecAuthFailed, errSecUserCanceled:
            .interactionRequired
        default:
            .unhandled(status)
        }
    }
}

protocol KeychainOperations: Sendable {
    func copyMatching(_ query: CFDictionary, result: UnsafeMutablePointer<CFTypeRef?>) -> OSStatus
    func add(_ attributes: CFDictionary) -> OSStatus
    func update(_ query: CFDictionary, attributes: CFDictionary) -> OSStatus
    func delete(_ query: CFDictionary) -> OSStatus
}

private struct SystemKeychainOperations: KeychainOperations {
    func copyMatching(_ query: CFDictionary, result: UnsafeMutablePointer<CFTypeRef?>) -> OSStatus {
        let uiPolicy = (query as NSDictionary)[kSecUseAuthenticationUI as String] as? String
        return Self.perform(allowInteraction: uiPolicy == (kSecUseAuthenticationUIAllow as String)) {
            SecItemCopyMatching(query, result)
        }
    }

    func add(_ attributes: CFDictionary) -> OSStatus {
        Self.perform(allowInteraction: false) {
            SecItemAdd(attributes, nil)
        }
    }

    func update(_ query: CFDictionary, attributes: CFDictionary) -> OSStatus {
        Self.perform(allowInteraction: false) {
            SecItemUpdate(query, attributes)
        }
    }

    func delete(_ query: CFDictionary) -> OSStatus {
        Self.perform(allowInteraction: false) {
            SecItemDelete(query)
        }
    }

    #if os(macOS)
    private static let interactionLock = NSLock()

    private static func perform(allowInteraction: Bool, _ operation: () -> OSStatus) -> OSStatus {
        interactionLock.lock()
        defer { interactionLock.unlock() }

        // The legacy login Keychain can ignore per-query no-UI settings.
        // This process-level switch is scoped to one Security call and restored.
        var previous = DarwinBoolean(false)
        let readStatus = SecKeychainGetUserInteractionAllowed(&previous)
        guard readStatus == errSecSuccess else { return readStatus }
        let setStatus = SecKeychainSetUserInteractionAllowed(allowInteraction)
        guard setStatus == errSecSuccess else { return setStatus }
        defer { _ = SecKeychainSetUserInteractionAllowed(previous.boolValue) }
        return operation()
    }
    #else
    private static func perform(allowInteraction: Bool, _ operation: () -> OSStatus) -> OSStatus {
        operation()
    }
    #endif
}

public struct KeychainAPIKeyProvider: APIKeyProviding {
    private let store: KeychainStore

    public init(store: KeychainStore = KeychainStore()) {
        self.store = store
    }

    public func apiKey() async throws -> String {
        do {
            guard let key = try await store.loadAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
                throw DictationError.missingAPIKey
            }
            return key
        } catch KeychainStore.KeychainError.interactionRequired {
            throw DictationError.apiKeyAccessRequired
        } catch is KeychainStore.KeychainError {
            throw DictationError.keychainUnavailable
        }
    }
}

public protocol APIKeyProviding: Sendable {
    func apiKey() async throws -> String
}
