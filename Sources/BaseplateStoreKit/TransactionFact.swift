import Foundation

/// A plain, StoreKit-free snapshot of the one transaction detail that decides entitlement.
///
/// This is the value type that lets entitlement logic be reasoned about — and unit-tested —
/// without the StoreKit runtime. The live ``EntitlementStore`` maps each verified
/// `StoreKit.Transaction` down to one of these (product id, refund state, optional expiry) and
/// hands them to the pure ``EntitlementEngine``; every test in this module builds them by hand.
///
/// A fact grants access when it is **not revoked** and **not past its expiry**. A non-expiring
/// purchase (a lifetime unlock, a non-consumable) carries `expirationDate == nil` and stays active
/// forever unless it is revoked. Because expiry is compared against an injected `now`, a cached
/// fact re-evaluated on a later launch expires correctly even with no network.
///
/// ```swift
/// let now = Date(timeIntervalSince1970: 1_000)
/// let lifetime = TransactionFact(productID: "pro.lifetime")
/// print(lifetime.isActive(at: now))   // true  (never expires, not revoked)
///
/// let lapsed = TransactionFact(
///     productID: "pro.monthly",
///     expirationDate: now.addingTimeInterval(-60)   // expired a minute ago
/// )
/// print(lapsed.isActive(at: now))    // false
/// print(lapsed.isExpired(at: now))   // true
/// ```
public struct TransactionFact: Sendable, Equatable, Hashable, Codable {

    /// The product identifier the transaction is for (matched against an entitlement's id set).
    public let productID: String

    /// Whether the transaction was revoked (refunded, or pulled for a billing/developer issue). A
    /// revoked fact never grants access, whatever its expiry.
    public let isRevoked: Bool

    /// When the transaction stops granting access, or `nil` for a non-expiring purchase (a lifetime
    /// unlock / non-consumable). Compared against an injected `now`, so it is deterministic in tests.
    public let expirationDate: Date?

    /// Creates a fact from the three details that decide entitlement.
    ///
    /// ```swift
    /// let fact = TransactionFact(productID: "pro.annual",
    ///                            expirationDate: Date(timeIntervalSince1970: 2_000))
    /// print(fact.isRevoked)   // false
    /// ```
    ///
    /// - Parameters:
    ///   - productID: The transaction's product identifier.
    ///   - isRevoked: `true` if the transaction carries a revocation date. Defaults to `false`.
    ///   - expirationDate: When access lapses, or `nil` for a non-expiring purchase. Defaults to `nil`.
    public init(productID: String, isRevoked: Bool = false, expirationDate: Date? = nil) {
        self.productID = productID
        self.isRevoked = isRevoked
        self.expirationDate = expirationDate
    }

    /// Whether this fact grants access at `now`: not revoked, and either non-expiring or not yet
    /// past its expiry.
    ///
    /// A fact whose `expirationDate` is exactly `now` is **not** active — expiry is inclusive, so the
    /// instant a subscription's period ends it stops granting access.
    ///
    /// ```swift
    /// let now = Date(timeIntervalSince1970: 500)
    /// let atExpiry = TransactionFact(productID: "p", expirationDate: now)
    /// print(atExpiry.isActive(at: now))   // false  (expiry is inclusive)
    /// ```
    ///
    /// - Parameter now: The current time to compare against.
    /// - Returns: `true` when the fact currently entitles the user.
    public func isActive(at now: Date) -> Bool {
        if isRevoked { return false }
        guard let expirationDate else { return true }
        return expirationDate > now
    }

    /// Whether this fact represents an entitlement that lapsed by time rather than by revocation:
    /// not revoked, had an `expirationDate`, and that date is at or before `now`.
    ///
    /// A revoked fact is never "expired" — it is simply gone. This is the signal that distinguishes
    /// a former subscriber (worth a win-back) from someone who never bought.
    ///
    /// ```swift
    /// let now = Date(timeIntervalSince1970: 1_000)
    /// let refunded = TransactionFact(productID: "p", isRevoked: true,
    ///                                expirationDate: now.addingTimeInterval(-1))
    /// print(refunded.isExpired(at: now))   // false  (revoked, not merely expired)
    /// ```
    ///
    /// - Parameter now: The current time to compare against.
    /// - Returns: `true` when the fact is a lapsed-by-time entitlement.
    public func isExpired(at now: Date) -> Bool {
        guard !isRevoked, let expirationDate else { return false }
        return expirationDate <= now
    }
}
