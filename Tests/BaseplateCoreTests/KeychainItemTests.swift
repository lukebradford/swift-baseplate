#if canImport(Security)

import Foundation
import Security
import Testing

@testable import BaseplateCore

/// An in-memory stand-in for the Security framework, keyed by service + account, so Keychain
/// tests are deterministic and never touch the real Keychain.
///
/// `@unchecked Sendable`: test-only storage guarded by a lock; the closures the backend exposes
/// capture `self`, so `self` must be `Sendable`. The suite drives it single-threaded.
private final class FakeKeychain: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    private func identity(_ query: [String: Any]) -> String {
        let service = query[kSecAttrService as String] as? String ?? ""
        let account = query[kSecAttrAccount as String] as? String ?? ""
        return "\(service)\u{0}\(account)"
    }

    var backend: KeychainBackend {
        KeychainBackend(
            copyMatching: { query in
                self.lock.lock()
                defer { self.lock.unlock() }
                if let data = self.storage[self.identity(query)] {
                    return (errSecSuccess, data)
                }
                return (errSecItemNotFound, nil)
            },
            add: { attributes in
                self.lock.lock()
                defer { self.lock.unlock() }
                let key = self.identity(attributes)
                guard self.storage[key] == nil else { return errSecDuplicateItem }
                self.storage[key] = (attributes[kSecValueData as String] as? Data) ?? Data()
                return errSecSuccess
            },
            update: { query, attributes in
                self.lock.lock()
                defer { self.lock.unlock() }
                let key = self.identity(query)
                guard self.storage[key] != nil else { return errSecItemNotFound }
                if let data = attributes[kSecValueData as String] as? Data {
                    self.storage[key] = data
                }
                return errSecSuccess
            },
            delete: { query in
                self.lock.lock()
                defer { self.lock.unlock() }
                let key = self.identity(query)
                guard self.storage[key] != nil else { return errSecItemNotFound }
                self.storage[key] = nil
                return errSecSuccess
            }
        )
    }
}

@Suite struct KeychainItemTests {

    @Test func string_set_get_round_trips() throws {
        let backend = FakeKeychain().backend
        let item = KeychainItem<String>(service: "svc", account: "token", backend: backend)
        try item.set("secret")
        #expect(try item.get() == "secret")
    }

    @Test func get_is_nil_when_absent() throws {
        let backend = FakeKeychain().backend
        let item = KeychainItem<String>(service: "svc", account: "missing", backend: backend)
        #expect(try item.get() == nil)
    }

    @Test func set_updates_existing_item_in_place() throws {
        let backend = FakeKeychain().backend
        let item = KeychainItem<String>(service: "svc", account: "token", backend: backend)
        try item.set("first")
        try item.set("second")
        #expect(try item.get() == "second")
    }

    @Test func delete_removes_the_item() throws {
        let backend = FakeKeychain().backend
        let item = KeychainItem<String>(service: "svc", account: "token", backend: backend)
        try item.set("value")
        try item.delete()
        #expect(try item.get() == nil)
    }

    @Test func delete_of_absent_item_does_not_throw() throws {
        let backend = FakeKeychain().backend
        let item = KeychainItem<String>(service: "svc", account: "nope", backend: backend)
        try item.delete()  // must not throw
    }

    @Test func data_round_trips() throws {
        let backend = FakeKeychain().backend
        let item = KeychainItem<Data>(service: "svc", account: "blob", backend: backend)
        let bytes = Data([0x01, 0x02, 0x03])
        try item.set(bytes)
        #expect(try item.get() == bytes)
    }

    struct License: Codable, Sendable, Equatable {
        let key: String
        let seats: Int
    }

    @Test func codable_round_trips() throws {
        let backend = FakeKeychain().backend
        let item = KeychainItem<License>.codable(
            service: "svc", account: "license", backend: backend)
        let license = License(key: "ABC", seats: 3)
        try item.set(license)
        #expect(try item.get() == license)
    }

    @Test func separate_accounts_do_not_collide() throws {
        let backend = FakeKeychain().backend
        let a = KeychainItem<String>(service: "svc", account: "a", backend: backend)
        let b = KeychainItem<String>(service: "svc", account: "b", backend: backend)
        try a.set("alpha")
        try b.set("bravo")
        #expect(try a.get() == "alpha")
        #expect(try b.get() == "bravo")
    }

    @Test func decoding_non_utf8_bytes_throws_deserialization_failed() throws {
        let backend = FakeKeychain().backend
        // Store bytes that are not valid UTF-8 via the Data API, then read them as a String.
        let raw = KeychainItem<Data>(service: "svc", account: "x", backend: backend)
        try raw.set(Data([0xFF, 0xFE]))
        let asString = KeychainItem<String>(service: "svc", account: "x", backend: backend)
        #expect(throws: KeychainError.deserializationFailed) {
            _ = try asString.get()
        }
    }

    @Test func unexpected_empty_data_throws() {
        // A backend that reports success but hands back no data.
        let backend = KeychainBackend(
            copyMatching: { _ in (errSecSuccess, nil) },
            add: { _ in errSecSuccess },
            update: { _, _ in errSecSuccess },
            delete: { _ in errSecSuccess }
        )
        let item = KeychainItem<String>(service: "svc", account: "x", backend: backend)
        #expect(throws: KeychainError.unexpectedData) {
            _ = try item.get()
        }
    }

    @Test func unhandled_status_is_surfaced() {
        let backend = KeychainBackend(
            copyMatching: { _ in (errSecAuthFailed, nil) },
            add: { _ in errSecAuthFailed },
            update: { _, _ in errSecAuthFailed },
            delete: { _ in errSecAuthFailed }
        )
        let item = KeychainItem<String>(service: "svc", account: "x", backend: backend)
        #expect(throws: KeychainError.unhandledStatus(errSecAuthFailed)) {
            _ = try item.get()
        }
    }
}

#endif
