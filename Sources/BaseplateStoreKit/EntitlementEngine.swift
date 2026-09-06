import Foundation

/// Pure, deterministic entitlement logic: given a set of ``TransactionFact`` and the current date,
/// decide whether a user is ``EntitlementState/entitled``, ``EntitlementState/expired``, or
/// ``EntitlementState/notEntitled`` — with no StoreKit import anywhere in reach.
///
/// This is where the real test coverage of the module lives. Everything that decides whether a
/// customer keeps what they paid for is here, in value types you can construct by hand, so it can
/// be exercised exhaustively without the StoreKit runtime, a network, or a clock. The live
/// ``EntitlementStore`` is a thin shell that maps `StoreKit.Transaction`s onto ``TransactionFact``
/// and calls into this type; its correctness rests on these tests.
///
/// An engine is configured with the set of product identifiers that grant one entitlement (a "Pro"
/// unlock might be granted by a monthly sub, an annual sub, and a lifetime purchase). Facts for
/// other products are ignored.
///
/// ```swift
/// let engine = EntitlementEngine(productIDs: ["pro.monthly", "pro.lifetime"])
/// let now = Date(timeIntervalSince1970: 1_000)
///
/// // An active lifetime purchase entitles.
/// let owned = [TransactionFact(productID: "pro.lifetime")]
/// print(engine.evaluate(facts: owned, now: now).isActive)   // true
///
/// // A lapsed subscription reads as expired, not merely "not entitled".
/// let lapsed = [TransactionFact(productID: "pro.monthly",
///                               expirationDate: now.addingTimeInterval(-1))]
/// print(engine.evaluate(facts: lapsed, now: now))           // expired
/// ```
public struct EntitlementEngine: Sendable, Equatable {

    /// The product identifiers that grant this entitlement. Facts for any other product are ignored.
    public let productIDs: Set<String>

    /// Creates an engine that grants its entitlement for any of `productIDs`.
    ///
    /// ```swift
    /// let engine = EntitlementEngine(productIDs: ["com.app.pro"])
    /// print(engine.productIDs.contains("com.app.pro"))   // true
    /// ```
    ///
    /// - Parameter productIDs: The set of identifiers that grant the entitlement. An empty set
    ///   makes ``evaluate(facts:now:)`` always ``EntitlementState/notEntitled``.
    public init(productIDs: Set<String>) {
        self.productIDs = productIDs
    }

    /// Derives the entitlement state from the given facts at `now`.
    ///
    /// The rule, applied only to facts whose product is in ``productIDs``:
    /// - any **active** fact (not revoked, not past expiry) ⇒ ``EntitlementState/entitled``;
    /// - otherwise, if any fact is **expired** (lapsed by time, not revoked) ⇒
    ///   ``EntitlementState/expired``;
    /// - otherwise (no matching facts, or all revoked) ⇒ ``EntitlementState/notEntitled``.
    ///
    /// Expiry is inclusive: a fact expiring exactly at `now` no longer entitles (see
    /// ``TransactionFact/isActive(at:)``).
    ///
    /// ```swift
    /// let engine = EntitlementEngine(productIDs: ["pro"])
    /// let now = Date(timeIntervalSince1970: 1_000)
    /// // Refunded purchase: revoked never grants, and revoked is not "expired".
    /// let refunded = [TransactionFact(productID: "pro", isRevoked: true)]
    /// print(engine.evaluate(facts: refunded, now: now))   // notEntitled
    /// ```
    ///
    /// - Parameters:
    ///   - facts: The transaction facts to consider (facts outside ``productIDs`` are skipped).
    ///   - now: The current time to evaluate expiry against.
    /// - Returns: The derived ``EntitlementState``.
    public func evaluate(facts: [TransactionFact], now: Date) -> EntitlementState {
        var sawExpired = false
        for fact in facts where productIDs.contains(fact.productID) {
            if fact.isActive(at: now) { return .entitled }
            if fact.isExpired(at: now) { sawExpired = true }
        }
        return sawExpired ? .expired : .notEntitled
    }

    /// Chooses which facts to trust — the freshly-fetched ones or the last-known-good cache — so
    /// that **an absence of evidence never revokes an active entitlement**.
    ///
    /// StoreKit reporting "no current entitlements" is ambiguous. It can mean the user genuinely
    /// lapsed or was refunded — in which case we *should* downgrade — or it can mean the on-device
    /// transaction database is not populated yet (a signed-out App Store account, a device
    /// migration mid-sync, an offline launch). Revoking a paying customer because their phone was
    /// briefly offline is the worst outcome this module can produce; a price is reversible, a
    /// one-star "it forgot I paid" review is not.
    ///
    /// `hasPurchaseHistory` is the discriminator, and it is *positive* evidence rather than a
    /// timer: it asks whether we can see this account's purchase history at all (a lapsed subscriber
    /// still has their expired transactions on record; an unsynced database has nothing). The rule:
    /// - `live` grants entitlement ⇒ trust `live` (a positive is always authoritative);
    /// - else `hasPurchaseHistory` is `true` ⇒ trust `live` (we can see history, so the negative is
    ///   real — a genuine lapse or refund downgrades);
    /// - else, only if `cached` was itself an active grant, keep `cached` (protect it); otherwise
    ///   trust `live`.
    ///
    /// ```swift
    /// let engine = EntitlementEngine(productIDs: ["pro"])
    /// let now = Date(timeIntervalSince1970: 1_000)
    /// let cached = [TransactionFact(productID: "pro")]   // last-known-good: owned
    ///
    /// // Offline launch: no live facts, and no visible history ⇒ keep the cached grant.
    /// let kept = engine.reconcile(live: [], cached: cached,
    ///                             hasPurchaseHistory: false, now: now)
    /// print(engine.evaluate(facts: kept, now: now))      // entitled
    ///
    /// // Genuine refund: no live facts, but history IS visible ⇒ honour the downgrade.
    /// let dropped = engine.reconcile(live: [], cached: cached,
    ///                                hasPurchaseHistory: true, now: now)
    /// print(engine.evaluate(facts: dropped, now: now))   // notEntitled
    /// ```
    ///
    /// - Parameters:
    ///   - live: The facts just fetched from StoreKit (possibly empty).
    ///   - cached: The last-known-good facts persisted from a previous resolution.
    ///   - hasPurchaseHistory: Whether any transaction history for these products is visible — the
    ///     positive evidence that makes a "not entitled" result trustworthy.
    ///   - now: The current time to evaluate expiry against.
    /// - Returns: The facts to adopt and persist as the new last-known-good.
    public func reconcile(
        live: [TransactionFact],
        cached: [TransactionFact],
        hasPurchaseHistory: Bool,
        now: Date
    ) -> [TransactionFact] {
        if evaluate(facts: live, now: now) == .entitled { return live }
        if hasPurchaseHistory { return live }
        return evaluate(facts: cached, now: now) == .entitled ? cached : live
    }
}
