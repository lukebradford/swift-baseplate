import Foundation
import Testing

@testable import BaseplateStoreKit

/// Confirms the thin live layer wires the (separately, exhaustively tested) engine to persistence
/// correctly. Every StoreKit seam is injected, so these run deterministically with no StoreKit
/// runtime, no network, and a fixed clock.
@MainActor
@Suite struct EntitlementStoreTests {

    private let now = Date(timeIntervalSince1970: 1_000)

    /// A mutable box a test can flip between `refresh()` calls, exposed as a `@Sendable` closure.
    ///
    /// `@unchecked Sendable`: test-only holder mutated single-threaded on the main actor.
    private final class Box<Value>: @unchecked Sendable {
        var value: Value
        init(_ value: Value) { self.value = value }
    }

    private func makeDefaults() -> UserDefaults {
        let name = "EntitlementStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func refresh_adopts_live_entitlement() async {
        let store = EntitlementStore(
            productIDs: ["pro"],
            defaults: makeDefaults(),
            now: { self.now },
            loadFacts: { [TransactionFact(productID: "pro")] },
            loadHasHistory: { true },
            loadProducts: { [] },
            sync: {},
            transactionUpdates: { AsyncStream { $0.finish() } })

        #expect(!store.hasEntitlement)  // nothing cached yet
        await store.refresh()
        #expect(store.hasEntitlement)
        #expect(store.state == .entitled)
        #expect(store.isEntitled("pro"))
    }

    @Test func last_known_good_survives_offline_relaunch() async {
        let defaults = makeDefaults()

        // First launch, online: resolves entitled and caches it.
        let online = EntitlementStore(
            productIDs: ["pro"],
            defaults: defaults,
            now: { self.now },
            loadFacts: { [TransactionFact(productID: "pro")] },
            loadHasHistory: { true },
            loadProducts: { [] },
            sync: {},
            transactionUpdates: { AsyncStream { $0.finish() } })
        await online.refresh()
        #expect(online.hasEntitlement)

        // Next launch, offline: no live facts, no visible history — the cache must hold the grant
        // even before any refresh (seeded in init) and across a refresh that finds nothing.
        let offline = EntitlementStore(
            productIDs: ["pro"],
            defaults: defaults,
            now: { self.now },
            loadFacts: { [] },
            loadHasHistory: { false },
            loadProducts: { [] },
            sync: {},
            transactionUpdates: { AsyncStream { $0.finish() } })
        #expect(offline.hasEntitlement)  // seeded from cache in init
        await offline.refresh()
        #expect(offline.hasEntitlement)  // absence of evidence did not revoke
    }

    @Test func genuine_refund_downgrades_when_history_visible() async {
        let defaults = makeDefaults()
        let liveFacts = Box<[TransactionFact]>([TransactionFact(productID: "pro")])

        let store = EntitlementStore(
            productIDs: ["pro"],
            defaults: defaults,
            now: { self.now },
            loadFacts: { liveFacts.value },
            loadHasHistory: { true },  // history is visible ⇒ a "not entitled" is trustworthy
            loadProducts: { [] },
            sync: {},
            transactionUpdates: { AsyncStream { $0.finish() } })

        await store.refresh()
        #expect(store.hasEntitlement)

        liveFacts.value = []  // refunded / lapsed
        await store.refresh()
        #expect(!store.hasEntitlement)
        #expect(store.state == .notEntitled)
    }

    @Test func subscription_expires_offline_by_time() async {
        let clock = Box(now)
        let defaults = makeDefaults()

        // Cache an active subscription that expires 100s out.
        let store = EntitlementStore(
            productIDs: ["pro.monthly"],
            defaults: defaults,
            now: { clock.value },
            loadFacts: {
                [
                    TransactionFact(
                        productID: "pro.monthly", expirationDate: self.now.addingTimeInterval(100))
                ]
            },
            loadHasHistory: { true },
            loadProducts: { [] },
            sync: {},
            transactionUpdates: { AsyncStream { $0.finish() } })
        await store.refresh()
        #expect(store.hasEntitlement)

        // Advance the clock past expiry. Offline, the live loader still surfaces the lapsed
        // transaction (the real `liveFacts` reads it from local storage via `Transaction.latest`),
        // so a full refresh resolves to `.expired` — a genuine win-back signal — rather than
        // silently collapsing to `.notEntitled`.
        clock.value = now.addingTimeInterval(500)
        let offline = EntitlementStore(
            productIDs: ["pro.monthly"],
            defaults: defaults,
            now: { clock.value },
            loadFacts: {
                [
                    TransactionFact(
                        productID: "pro.monthly", expirationDate: self.now.addingTimeInterval(100))
                ]
            },
            loadHasHistory: { true },
            loadProducts: { [] },
            sync: {},
            transactionUpdates: { AsyncStream { $0.finish() } })
        await offline.refresh()
        #expect(!offline.hasEntitlement)
        #expect(offline.state == .expired)
    }

    @Test func restore_syncs_then_resolves() async {
        let synced = Box(false)
        let store = EntitlementStore(
            productIDs: ["pro"],
            defaults: makeDefaults(),
            now: { self.now },
            loadFacts: { synced.value ? [TransactionFact(productID: "pro")] : [] },
            loadHasHistory: { synced.value },
            loadProducts: { [] },
            sync: { synced.value = true },
            transactionUpdates: { AsyncStream { $0.finish() } })

        let state = await store.restore()
        #expect(state == .entitled)
        #expect(store.hasEntitlement)
    }

    @Test func restore_swallows_sync_failure_and_still_resolves() async {
        struct SyncError: Error {}
        let defaults = makeDefaults()

        // Pre-cache an entitlement so a failed sync + refresh still resolves from last-known-good.
        let seed = EntitlementStore(
            productIDs: ["pro"],
            defaults: defaults,
            now: { self.now },
            loadFacts: { [TransactionFact(productID: "pro")] },
            loadHasHistory: { true },
            loadProducts: { [] },
            sync: {},
            transactionUpdates: { AsyncStream { $0.finish() } })
        await seed.refresh()

        let store = EntitlementStore(
            productIDs: ["pro"],
            defaults: defaults,
            now: { self.now },
            loadFacts: { [] },
            loadHasHistory: { false },
            loadProducts: { [] },
            sync: { throw SyncError() },
            transactionUpdates: { AsyncStream { $0.finish() } })
        let state = await store.restore()
        #expect(state == .entitled)  // cached grant preserved despite the throw
    }

    @Test func load_product_info_populates_products() async {
        let store = EntitlementStore(
            productIDs: ["pro"],
            defaults: makeDefaults(),
            now: { self.now },
            loadFacts: { [] },
            loadHasHistory: { false },
            // Product has no public init; the live product-loading path is integration-tested.
            loadProducts: { [] },
            sync: {},
            transactionUpdates: { AsyncStream { $0.finish() } })
        await store.loadProductInfo()
        #expect(store.products.isEmpty)
    }

    @Test func corrupt_cache_does_not_grant_entitlement() async {
        let defaults = makeDefaults()
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: "baseplate.storekit.entitlement")
        let store = EntitlementStore(
            productIDs: ["pro"],
            defaults: defaults,
            now: { self.now },
            loadFacts: { [] },
            loadHasHistory: { false },
            loadProducts: { [] },
            sync: {},
            transactionUpdates: { AsyncStream { $0.finish() } })
        #expect(!store.hasEntitlement)  // corrupt cache discarded by CodableDefaultsStore
        #expect(store.facts.isEmpty)
    }
}
