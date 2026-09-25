import Foundation
import LocalAuthentication
import Security
import Testing
@testable import CohereVoiceCore

@Suite(.serialized)
struct KeychainStoreTests {
    @Test func missingKeyReturnsNilWithoutInteraction() async throws {
        let operations = FakeKeychainOperations(copyStatus: errSecItemNotFound)
        let store = makeStore(operations)

        #expect(try await store.loadAPIKey() == nil)
        #expect(operations.readInteractionAllowed == false)
    }

    @Test func successfulReadReturnsKeyWithoutInteraction() async throws {
        let operations = FakeKeychainOperations(copyStatus: errSecSuccess, storedKey: "test-key")
        let store = makeStore(operations)

        #expect(try await store.loadAPIKey() == "test-key")
        #expect(operations.readInteractionAllowed == false)
    }

    @Test func authorizationRequiredIsDistinctFromMissing() async {
        let operations = FakeKeychainOperations(copyStatus: errSecInteractionNotAllowed)
        let store = makeStore(operations)

        await #expect(throws: KeychainStore.KeychainError.interactionRequired) {
            try await store.loadAPIKey()
        }
        #expect(operations.readInteractionAllowed == false)
    }

    @Test func unexpectedReadErrorIsPreserved() async {
        let operations = FakeKeychainOperations(copyStatus: errSecNotAvailable)
        let store = makeStore(operations)

        await #expect(throws: KeychainStore.KeychainError.unhandled(errSecNotAvailable)) {
            try await store.loadAPIKey()
        }
    }

    @Test func repairReadAllowsInteractionOnlyWhenRequested() async throws {
        let operations = FakeKeychainOperations(copyStatus: errSecSuccess, storedKey: "test-key")
        let store = makeStore(operations)

        #expect(try await store.repairAPIKeyAccess() == "test-key")
        #expect(operations.readInteractionAllowed == true)
        #expect(try await store.loadAPIKey() == "test-key")
        #expect(operations.readInteractionAllowed == false)
    }

    @Test func saveUpdatesExistingItem() async throws {
        let operations = FakeKeychainOperations(updateStatus: errSecSuccess, storedKey: "old")
        let store = makeStore(operations)

        try await store.saveAPIKey("new")
        #expect(operations.calls == ["update"])
        #expect(operations.storedKey == "new")
        #expect(operations.updateInteractionAllowed == false)
    }

    @Test func saveAddsOnlyWhenItemIsMissing() async throws {
        let operations = FakeKeychainOperations(updateStatus: errSecItemNotFound)
        let store = makeStore(operations)

        try await store.saveAPIKey("new")
        #expect(operations.calls == ["update", "add"])
        #expect(operations.storedKey == "new")
    }

    @Test func failedUpdateLeavesOldKeyUntouched() async {
        let operations = FakeKeychainOperations(updateStatus: errSecInteractionNotAllowed, storedKey: "old")
        let store = makeStore(operations)

        await #expect(throws: KeychainStore.KeychainError.interactionRequired) {
            try await store.saveAPIKey("new")
        }
        #expect(operations.calls == ["update"])
        #expect(operations.storedKey == "old")
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["COHEREVOICE_KEYCHAIN_INTEGRATION"] == "1"))
    func realKeychainRoundTripWithDisposableItem() async throws {
        let store = KeychainStore(
            service: "com.shahab.coherevoice.integration.\(UUID().uuidString)",
            account: "disposable-test-key"
        )
        do {
            try await store.saveAPIKey("test-value")
            #expect(try await store.loadAPIKey() == "test-value")
            try await store.saveAPIKey("replacement")
            #expect(try await store.loadAPIKey() == "replacement")
            try await store.deleteAPIKey()
            #expect(try await store.loadAPIKey() == nil)
        } catch {
            try? await store.deleteAPIKey()
            throw error
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["COHEREVOICE_LEGACY_TEST_SERVICE"] != nil))
    func cliCreatedItemRequiresExplicitRepair() async {
        guard let service = ProcessInfo.processInfo.environment["COHEREVOICE_LEGACY_TEST_SERVICE"] else {
            return
        }
        let store = KeychainStore(service: service, account: "disposable-test-key")
        await #expect(throws: KeychainStore.KeychainError.interactionRequired) {
            try await store.loadAPIKey()
        }
    }

    private func makeStore(_ operations: FakeKeychainOperations) -> KeychainStore {
        KeychainStore(service: "coherevoice-tests", account: "api-key", operations: operations)
    }
}

private final class FakeKeychainOperations: KeychainOperations, @unchecked Sendable {
    private struct State {
        var copyStatus: OSStatus
        var updateStatus: OSStatus
        var storedKey: String?
        var calls: [String] = []
        var readInteractionAllowed: Bool?
        var updateInteractionAllowed: Bool?
    }

    private let lock = NSLock()
    private var state: State

    init(
        copyStatus: OSStatus = errSecItemNotFound,
        updateStatus: OSStatus = errSecItemNotFound,
        storedKey: String? = nil
    ) {
        state = State(copyStatus: copyStatus, updateStatus: updateStatus, storedKey: storedKey)
    }

    var calls: [String] { lock.withLock { state.calls } }
    var storedKey: String? { lock.withLock { state.storedKey } }
    var readInteractionAllowed: Bool? { lock.withLock { state.readInteractionAllowed } }
    var updateInteractionAllowed: Bool? { lock.withLock { state.updateInteractionAllowed } }

    func copyMatching(_ query: CFDictionary, result: UnsafeMutablePointer<CFTypeRef?>) -> OSStatus {
        let uiSetting = (query as NSDictionary)[kSecUseAuthenticationUI as String] as? String
        return lock.withLock {
            state.calls.append("read")
            state.readInteractionAllowed = uiSetting == (kSecUseAuthenticationUIAllow as String)
            if state.copyStatus == errSecSuccess, let storedKey = state.storedKey {
                result.pointee = Data(storedKey.utf8) as CFData
            }
            return state.copyStatus
        }
    }

    func add(_ attributes: CFDictionary) -> OSStatus {
        let data = (attributes as NSDictionary)[kSecValueData as String] as? Data
        return lock.withLock {
            state.calls.append("add")
            state.storedKey = data.flatMap { String(data: $0, encoding: .utf8) }
            return errSecSuccess
        }
    }

    func update(_ query: CFDictionary, attributes: CFDictionary) -> OSStatus {
        let uiSetting = (query as NSDictionary)[kSecUseAuthenticationUI as String] as? String
        let data = (attributes as NSDictionary)[kSecValueData as String] as? Data
        return lock.withLock {
            state.calls.append("update")
            state.updateInteractionAllowed = uiSetting == (kSecUseAuthenticationUIAllow as String)
            if state.updateStatus == errSecSuccess {
                state.storedKey = data.flatMap { String(data: $0, encoding: .utf8) }
            }
            return state.updateStatus
        }
    }

    func delete(_ query: CFDictionary) -> OSStatus {
        lock.withLock {
            state.calls.append("delete")
            state.storedKey = nil
            return errSecSuccess
        }
    }
}
