#if canImport(Security)

import Foundation
import Security

/// The typed errors thrown by ``KeychainItem``.
///
/// Every case is deterministic and comparable, so tests can assert the exact failure without
/// matching on opaque `NSError` domains. Serialization failures are collapsed to
/// ``serializationFailed`` / ``deserializationFailed`` (rather than carrying an arbitrary
/// underlying `Error`) to keep the type `Sendable` and `Equatable`.
///
/// ```swift
/// do {
///     _ = try KeychainItem<String>(service: "svc", account: "acct").get()
/// } catch let error as KeychainError {
///     if case .unhandledStatus(let code) = error {
///         print("Keychain OSStatus: \(code)")
///     }
/// }
/// ```
public enum KeychainError: Error, Equatable, Sendable {

    /// A Keychain call returned an `OSStatus` other than success or "item not found".
    ///
    /// The associated value is the raw status; pass it to `SecCopyErrorMessageString` for a
    /// human-readable description when logging.
    case unhandledStatus(OSStatus)

    /// The item existed but the Keychain returned no data for it (an unexpected, malformed result).
    case unexpectedData

    /// The value could not be encoded to `Data` for storage (e.g. a non-UTF-8 string, or a
    /// `Codable` value that failed to JSON-encode).
    case serializationFailed

    /// The stored `Data` could not be decoded back into the value type (e.g. non-UTF-8 bytes, or
    /// JSON that no longer matches the type).
    case deserializationFailed
}

#endif
