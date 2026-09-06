import Foundation

/// The three states a user can be in for one entitlement, derived purely by ``EntitlementEngine``.
///
/// The distinction between ``expired`` and ``notEntitled`` is deliberate and worth keeping: a
/// lapsed subscriber (``expired``) is a former customer a paywall can address differently — "your
/// Pro access ended, resubscribe" — from someone who never bought (``notEntitled``). Access gates
/// should key off ``isActive``, which is `true` only for ``entitled``.
///
/// ```swift
/// let engine = EntitlementEngine(productIDs: ["pro.monthly"])
/// let now = Date(timeIntervalSince1970: 1_000)
/// let lapsed = [TransactionFact(productID: "pro.monthly",
///                               expirationDate: now.addingTimeInterval(-1))]
/// let state = engine.evaluate(facts: lapsed, now: now)
/// print(state)              // expired
/// print(state.isActive)     // false
/// ```
public enum EntitlementState: String, Sendable, Equatable, Hashable, Codable {

    /// The user currently owns the entitlement: an active, non-revoked purchase or subscription.
    case entitled

    /// The user had the entitlement but it lapsed by time (a subscription that was not renewed),
    /// and nothing else currently grants it.
    case expired

    /// The user does not have the entitlement and has no lapsed one — never bought, or was refunded.
    case notEntitled

    /// Whether the entitlement is currently in force. `true` only for ``entitled``; the single
    /// value a feature gate should read.
    ///
    /// ```swift
    /// print(EntitlementState.entitled.isActive)      // true
    /// print(EntitlementState.expired.isActive)       // false
    /// print(EntitlementState.notEntitled.isActive)   // false
    /// ```
    public var isActive: Bool { self == .entitled }
}
