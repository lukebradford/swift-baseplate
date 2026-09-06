#if canImport(Security)

import Foundation
import Security

/// A tiny, dependency-free store for a single generic-password Keychain item, keyed by a
/// `service` + `account` pair, with typed get / set / delete.
///
/// Reach for this when a value must survive app deletion and reinstall, or roam to a new device
/// via encrypted backup — a trial's install date, a license token, a small secret. (Keychain items
/// persist across an uninstall on modern iOS, which is exactly why they are the right home for an
/// anti-abuse "you already had your trial" signal.) By default items are stored with
/// `kSecAttrAccessibleAfterFirstUnlock`, which keeps the value available to background work after
/// the first unlock and includes it in encrypted backups; choose a `…ThisDeviceOnly` accessibility
/// to keep it off backups.
///
/// The type is generic over the stored `Value`. Convenience initializers cover `String` and `Data`
/// directly; ``codable(service:account:accessibility:)`` stores any `Codable` value as JSON. All
/// three operations `throw` a typed ``KeychainError``.
///
/// - Note: The Keychain is an injected side effect. Production uses the real Security framework;
///   tests inject an in-memory backend so the suite is deterministic and never touches the real
///   Keychain. Because the whole file is gated on `canImport(Security)`, the portable surface still
///   builds where Security is unavailable.
///
/// ```swift
/// let token = KeychainItem<String>(service: "com.example.app", account: "apiToken")
/// try token.set("secret-123")
/// print(try token.get() ?? "—")   // "secret-123"
/// try token.delete()
/// print(try token.get() ?? "—")   // "—"
/// ```
public struct KeychainItem<Value>: Sendable {

    /// The Keychain service (typically a reverse-DNS bundle-ish identifier) this item lives under.
    public let service: String

    /// The account name distinguishing this item within its ``service``.
    public let account: String

    /// The accessibility class applied when the item is first written.
    public let accessibility: KeychainAccessibility

    private let encode: @Sendable (Value) throws -> Data
    private let decode: @Sendable (Data) throws -> Value
    private let backend: KeychainBackend

    /// The designated initializer. Public callers use the `String` / `Data` / `codable`
    /// conveniences below; the injectable `backend` exists for deterministic tests.
    init(
        service: String,
        account: String,
        accessibility: KeychainAccessibility,
        backend: KeychainBackend = .live,
        encode: @escaping @Sendable (Value) throws -> Data,
        decode: @escaping @Sendable (Data) throws -> Value
    ) {
        self.service = service
        self.account = account
        self.accessibility = accessibility
        self.backend = backend
        self.encode = encode
        self.decode = decode
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    /// Returns the stored value, or `nil` if no item exists for this service + account.
    ///
    /// ```swift
    /// let item = KeychainItem<Data>(service: "svc", account: "acct")
    /// print(try item.get() == nil)   // true, before anything is written
    /// ```
    ///
    /// - Returns: The decoded value, or `nil` when the item is absent.
    /// - Throws: ``KeychainError/unexpectedData`` if the item exists but returned no bytes,
    ///   ``KeychainError/deserializationFailed`` if the bytes cannot be decoded to `Value`, or
    ///   ``KeychainError/unhandledStatus(_:)`` for any other Keychain failure.
    public func get() throws -> Value? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        let (status, data) = backend.copyMatching(query)
        switch status {
        case errSecSuccess:
            guard let data else { throw KeychainError.unexpectedData }
            return try decode(data)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandledStatus(status)
        }
    }

    /// Stores `value`, creating the item if absent or updating it in place if it already exists.
    ///
    /// The ``accessibility`` class is applied on creation. Updating an existing item preserves the
    /// accessibility it was created with.
    ///
    /// ```swift
    /// let item = KeychainItem<String>(service: "svc", account: "acct")
    /// try item.set("hello")
    /// try item.set("world")   // updates in place
    /// print(try item.get() ?? "—")   // "world"
    /// ```
    ///
    /// - Parameter value: The value to persist.
    /// - Throws: ``KeychainError/serializationFailed`` if `value` cannot be encoded, or
    ///   ``KeychainError/unhandledStatus(_:)`` for a Keychain add/update failure.
    public func set(_ value: Value) throws {
        let data = try encode(value)
        let query = baseQuery()
        let attributes: [String: Any] = [kSecValueData as String: data]

        let updateStatus = backend.update(query, attributes)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = accessibility.rawValue
            let addStatus = backend.add(addQuery)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledStatus(addStatus)
            }
        default:
            throw KeychainError.unhandledStatus(updateStatus)
        }
    }

    /// Deletes the item. Deleting a non-existent item is not an error.
    ///
    /// ```swift
    /// let item = KeychainItem<String>(service: "svc", account: "acct")
    /// try item.delete()   // no-op, and does not throw, when nothing is stored
    /// ```
    ///
    /// - Throws: ``KeychainError/unhandledStatus(_:)`` for a Keychain delete failure other than
    ///   "item not found".
    public func delete() throws {
        let status = backend.delete(baseQuery())
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }
}

extension KeychainItem where Value == Data {
    /// Creates a store for raw `Data`.
    ///
    /// ```swift
    /// let item = KeychainItem<Data>(service: "svc", account: "blob")
    /// try item.set(Data([0x01, 0x02]))
    /// print(try item.get()?.count ?? 0)   // 2
    /// ```
    ///
    /// - Parameters:
    ///   - service: The Keychain service.
    ///   - account: The account within the service.
    ///   - accessibility: When the value is available. Defaults to `.afterFirstUnlock`.
    public init(
        service: String,
        account: String,
        accessibility: KeychainAccessibility = .afterFirstUnlock
    ) {
        self.init(service: service, account: account, accessibility: accessibility, backend: .live)
    }

    /// Backend-injecting variant for deterministic tests.
    init(
        service: String,
        account: String,
        accessibility: KeychainAccessibility = .afterFirstUnlock,
        backend: KeychainBackend
    ) {
        self.init(
            service: service,
            account: account,
            accessibility: accessibility,
            backend: backend,
            encode: { $0 },
            decode: { $0 }
        )
    }
}

extension KeychainItem where Value == String {
    /// Creates a store for a `String`, encoded as UTF-8.
    ///
    /// ```swift
    /// let item = KeychainItem<String>(service: "svc", account: "name")
    /// try item.set("Ada")
    /// print(try item.get() ?? "—")   // "Ada"
    /// ```
    ///
    /// - Parameters:
    ///   - service: The Keychain service.
    ///   - account: The account within the service.
    ///   - accessibility: When the value is available. Defaults to `.afterFirstUnlock`.
    public init(
        service: String,
        account: String,
        accessibility: KeychainAccessibility = .afterFirstUnlock
    ) {
        self.init(service: service, account: account, accessibility: accessibility, backend: .live)
    }

    /// Backend-injecting variant for deterministic tests.
    init(
        service: String,
        account: String,
        accessibility: KeychainAccessibility = .afterFirstUnlock,
        backend: KeychainBackend
    ) {
        self.init(
            service: service,
            account: account,
            accessibility: accessibility,
            backend: backend,
            encode: { string in
                guard let data = string.data(using: .utf8) else {
                    throw KeychainError.serializationFailed
                }
                return data
            },
            decode: { data in
                guard let string = String(data: data, encoding: .utf8) else {
                    throw KeychainError.deserializationFailed
                }
                return string
            }
        )
    }
}

extension KeychainItem {
    /// Creates a store that persists any `Codable` value as JSON.
    ///
    /// ```swift
    /// struct License: Codable { let key: String; let seats: Int }
    /// let item = KeychainItem<License>.codable(service: "svc", account: "license")
    /// try item.set(License(key: "ABC", seats: 3))
    /// print(try item.get()?.seats ?? 0)   // 3
    /// ```
    ///
    /// - Parameters:
    ///   - service: The Keychain service.
    ///   - account: The account within the service.
    ///   - accessibility: When the value is available. Defaults to `.afterFirstUnlock`.
    /// - Returns: A `KeychainItem` whose `set`/`get` JSON-encode and JSON-decode the value,
    ///   surfacing any coding failure as ``KeychainError/serializationFailed`` /
    ///   ``KeychainError/deserializationFailed``.
    public static func codable(
        service: String,
        account: String,
        accessibility: KeychainAccessibility = .afterFirstUnlock
    ) -> KeychainItem<Value> where Value: Codable & Sendable {
        codable(service: service, account: account, accessibility: accessibility, backend: .live)
    }

    /// Backend-injecting variant for deterministic tests.
    static func codable(
        service: String,
        account: String,
        accessibility: KeychainAccessibility = .afterFirstUnlock,
        backend: KeychainBackend
    ) -> KeychainItem<Value> where Value: Codable & Sendable {
        KeychainItem(
            service: service,
            account: account,
            accessibility: accessibility,
            backend: backend,
            encode: { value in
                do { return try JSONEncoder().encode(value) } catch {
                    throw KeychainError.serializationFailed
                }
            },
            decode: { data in
                do { return try JSONDecoder().decode(Value.self, from: data) } catch {
                    throw KeychainError.deserializationFailed
                }
            }
        )
    }
}

#endif
