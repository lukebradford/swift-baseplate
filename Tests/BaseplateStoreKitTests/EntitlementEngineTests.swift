import Foundation
import Testing

@testable import BaseplateStoreKit

/// The core coverage of the module: exhaustive, deterministic, StoreKit-free entitlement logic.
@Suite struct EntitlementEngineTests {

    private let now = Date(timeIntervalSince1970: 1_000)
    private let engine = EntitlementEngine(productIDs: ["pro.monthly", "pro.lifetime"])

    // MARK: evaluate

    @Test func active_lifetime_purchase_is_entitled() {
        let facts = [TransactionFact(productID: "pro.lifetime")]
        #expect(engine.evaluate(facts: facts, now: now) == .entitled)
    }

    @Test func active_subscription_is_entitled() {
        let facts = [
            TransactionFact(productID: "pro.monthly", expirationDate: now.addingTimeInterval(60))
        ]
        #expect(engine.evaluate(facts: facts, now: now) == .entitled)
    }

    @Test func revoked_purchase_is_not_entitled() {
        let facts = [TransactionFact(productID: "pro.lifetime", isRevoked: true)]
        #expect(engine.evaluate(facts: facts, now: now) == .notEntitled)
    }

    @Test func expired_subscription_reads_as_expired() {
        let facts = [
            TransactionFact(productID: "pro.monthly", expirationDate: now.addingTimeInterval(-1))
        ]
        #expect(engine.evaluate(facts: facts, now: now) == .expired)
    }

    @Test func subscription_at_exact_expiry_reads_as_expired() {
        let facts = [TransactionFact(productID: "pro.monthly", expirationDate: now)]
        #expect(engine.evaluate(facts: facts, now: now) == .expired)
    }

    @Test func empty_facts_are_not_entitled() {
        #expect(engine.evaluate(facts: [], now: now) == .notEntitled)
    }

    @Test func facts_for_other_products_are_ignored() {
        let facts = [TransactionFact(productID: "com.other.thing")]
        #expect(engine.evaluate(facts: facts, now: now) == .notEntitled)
    }

    @Test func active_fact_wins_over_expired_fact() {
        // A lapsed monthly plus an owned lifetime ⇒ entitled, not expired.
        let facts = [
            TransactionFact(productID: "pro.monthly", expirationDate: now.addingTimeInterval(-1)),
            TransactionFact(productID: "pro.lifetime"),
        ]
        #expect(engine.evaluate(facts: facts, now: now) == .entitled)
    }

    @Test func revoked_plus_expired_reads_as_expired() {
        let facts = [
            TransactionFact(productID: "pro.lifetime", isRevoked: true),
            TransactionFact(productID: "pro.monthly", expirationDate: now.addingTimeInterval(-1)),
        ]
        #expect(engine.evaluate(facts: facts, now: now) == .expired)
    }

    @Test func empty_product_set_never_entitles() {
        let none = EntitlementEngine(productIDs: [])
        let facts = [TransactionFact(productID: "pro.lifetime")]
        #expect(none.evaluate(facts: facts, now: now) == .notEntitled)
    }

    @Test func clock_moving_backward_before_expiry_re_entitles() {
        // A subscription cached while active; the clock later reads a time before expiry again
        // (e.g. device clock corrected) ⇒ still entitled.
        let facts = [
            TransactionFact(productID: "pro.monthly", expirationDate: now.addingTimeInterval(100))
        ]
        let earlier = now.addingTimeInterval(-500)
        #expect(engine.evaluate(facts: facts, now: earlier) == .entitled)
    }

    // MARK: reconcile — last-known-good

    @Test func reconcile_trusts_live_when_it_grants() {
        let live = [TransactionFact(productID: "pro.lifetime")]
        let cached: [TransactionFact] = []
        let adopted = engine.reconcile(
            live: live, cached: cached, hasPurchaseHistory: false, now: now)
        #expect(adopted == live)
    }

    @Test func reconcile_keeps_cached_grant_when_no_evidence() {
        // Offline / unsynced: live empty AND no visible history ⇒ protect the cached grant.
        let cached = [TransactionFact(productID: "pro.lifetime")]
        let adopted = engine.reconcile(
            live: [], cached: cached, hasPurchaseHistory: false, now: now)
        #expect(adopted == cached)
        #expect(engine.evaluate(facts: adopted, now: now) == .entitled)
    }

    @Test func reconcile_downgrades_when_history_is_visible() {
        // Genuine refund/lapse: live empty but history IS visible ⇒ honour the downgrade.
        let cached = [TransactionFact(productID: "pro.lifetime")]
        let adopted = engine.reconcile(live: [], cached: cached, hasPurchaseHistory: true, now: now)
        #expect(adopted.isEmpty)
        #expect(engine.evaluate(facts: adopted, now: now) == .notEntitled)
    }

    @Test func reconcile_does_not_protect_a_non_active_cache() {
        // Cached was itself expired (not an active grant): nothing to protect, adopt live.
        let cached = [
            TransactionFact(productID: "pro.monthly", expirationDate: now.addingTimeInterval(-1))
        ]
        let adopted = engine.reconcile(
            live: [], cached: cached, hasPurchaseHistory: false, now: now)
        #expect(adopted.isEmpty)
    }

    @Test func reconcile_replaces_cache_with_stronger_live() {
        // Cached expired subscription, live now shows a lifetime purchase ⇒ adopt live.
        let cached = [
            TransactionFact(productID: "pro.monthly", expirationDate: now.addingTimeInterval(-1))
        ]
        let live = [TransactionFact(productID: "pro.lifetime")]
        let adopted = engine.reconcile(
            live: live, cached: cached, hasPurchaseHistory: true, now: now)
        #expect(adopted == live)
    }

    @Test func reconcile_protects_active_cache_even_if_cache_expires_later() {
        // Cache active now; kept offline; a later evaluation past its expiry naturally reads expired.
        let cached = [
            TransactionFact(productID: "pro.monthly", expirationDate: now.addingTimeInterval(100))
        ]
        let adopted = engine.reconcile(
            live: [], cached: cached, hasPurchaseHistory: false, now: now)
        #expect(adopted == cached)
        // Same cached facts, evaluated after expiry with no fresh data:
        let later = now.addingTimeInterval(500)
        #expect(engine.evaluate(facts: adopted, now: later) == .expired)
    }
}
