#if canImport(Security)

import Foundation
import Security

/// The seam between ``KeychainItem`` and the Security framework, so the Keychain — a process-wide
/// side effect — can be replaced with an in-memory fake in tests.
///
/// Production uses ``live``, which forwards to `SecItemCopyMatching` / `SecItemAdd` /
/// `SecItemUpdate` / `SecItemDelete`. Tests inject a fake with the same four closures, keeping the
/// suite deterministic and off the real Keychain. This type is intentionally `internal`: it is an
/// implementation detail, not public surface.
struct KeychainBackend: Sendable {

    /// Looks up an item. Returns the status and, on success, the item's data.
    let copyMatching: @Sendable (_ query: [String: Any]) -> (OSStatus, Data?)

    /// Adds a new item described by `attributes`. Returns the status.
    let add: @Sendable (_ attributes: [String: Any]) -> OSStatus

    /// Updates the item matching `query` with `attributes`. Returns the status.
    let update: @Sendable (_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus

    /// Deletes the item matching `query`. Returns the status.
    let delete: @Sendable (_ query: [String: Any]) -> OSStatus

    /// The real Security-framework backend.
    static let live = KeychainBackend(
        copyMatching: { query in
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            return (status, result as? Data)
        },
        add: { attributes in
            SecItemAdd(attributes as CFDictionary, nil)
        },
        update: { query, attributes in
            SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        },
        delete: { query in
            SecItemDelete(query as CFDictionary)
        }
    )
}

#endif
