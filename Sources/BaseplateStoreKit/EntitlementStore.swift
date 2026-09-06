import BaseplateCore
import Foundation
import Observation
import StoreKit

/// The live, observable entitlement layer for a no-backend indie app: it loads products, watches
/// `Transaction.updates`, feeds verified transactions through the pure ``EntitlementEngine``, and
/// caches the derived facts so a known entitlement survives an offline launch.
///
/// This type is deliberately **thin**. It owns only the messy, hard-to-test parts — talking to
/// StoreKit and persisting — and delegates every actual decision (entitled vs expired, whether an
/// empty result may revoke a cached grant) to ``EntitlementEngine``, which is exhaustively
/// unit-tested. Every StoreKit touch point is injected as a closure with a live default, so this
/// class can also be driven deterministically in unit tests with no StoreKit runtime, and the live
/// behaviour is confirmed by integration tests (below).
///
/// It is `@MainActor` and `@Observable`: read ``state``, ``hasEntitlement``, or
/// ``isEntitled(_:)`` from SwiftUI and views update when a purchase, restore, or background
/// renewal changes things. The last-known-good facts are cached via `BaseplateCore`'s
/// `CodableDefaultsStore`, so on the next launch — even with no network — ``state`` reflects the
/// prior resolution. A subscription that lapsed in the meantime reads as
/// ``EntitlementState/expired`` (not ``EntitlementState/notEntitled``): both the live loader and
/// the cache preserve the expired transaction, and expiry is evaluated against the current date.
///
/// - Important: The cache is a **UX convenience for offline launches, not a security boundary.** A
///   determined user can edit `UserDefaults` to grant themselves entitlement, and on a device with
///   no network the forged grant will be believed until StoreKit history becomes visible again.
///   That is an accepted trade-off for a no-backend library: the authoritative gate is StoreKit's
///   *verified* `Transaction`, which this type re-checks on every `refresh()`. For hard revenue
///   protection, validate entitlements server-side (or use a backend like RevenueCat). Do not put
///   anything genuinely sensitive behind this cache.
///
/// ## Running the live integration tests in Xcode
///
/// The unit tests in this module are deterministic and must not require StoreKit, so they inject
/// fakes and never touch the network. To exercise the *real* StoreKit path, use the bundled
/// StoreKit configuration and Xcode's local test environment:
///
/// 1. In Xcode, edit the test scheme → **Run**/**Test** → **Options** →
///    **StoreKit Configuration** and select
///    `Tests/BaseplateStoreKitTests/Fixtures/Products.storekit`.
/// 2. Construct an `EntitlementStore` with the **default** closures (no injection) and its
///    `productIDs` set to the fixture's ids (`com.example.baseplate.pro.lifetime`,
///    `com.example.baseplate.pro.monthly`).
/// 3. `await store.start()`, drive a purchase from the StoreKit test UI (or Xcode's Transaction
///    Manager), and assert `store.hasEntitlement`. Manage/expire/refund transactions from the
///    Transaction Manager to observe ``EntitlementState/expired`` and the revoke path.
///
/// Keep that integration target separate from the swift-testing unit suite, which stays green with
/// no simulator and no StoreKit.
///
/// ```swift
/// // Deterministic construction — inject fakes, no StoreKit needed.
/// let store = EntitlementStore(
///     productIDs: ["pro.lifetime"],
///     defaults: UserDefaults(suiteName: "example")!,
///     loadFacts: { [TransactionFact(productID: "pro.lifetime")] },
///     loadHasHistory: { true },
///     loadProducts: { [] },
///     sync: {},
///     transactionUpdates: { AsyncStream { $0.finish() } }
/// )
/// await store.refresh()
/// print(store.hasEntitlement)               // true
/// print(store.isEntitled("pro.lifetime"))   // true
/// ```
@MainActor
@Observable
public final class EntitlementStore {

    /// The last-resolved transaction facts backing every entitlement query. Reassigned on each
    /// ``refresh()``; reading ``state``/``isEntitled(_:)`` in a view tracks this, so the UI updates.
    public private(set) var facts: [TransactionFact]

    /// The loaded products, for a paywall's localized names and prices. Empty until
    /// ``loadProductInfo()`` (or ``start()``) returns, or when offline.
    public private(set) var products: [Product] = []

    @ObservationIgnored private let engine: EntitlementEngine
    @ObservationIgnored private let cache: CodableDefaultsStore<[TransactionFact]>
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let loadFacts: @Sendable () async -> [TransactionFact]
    @ObservationIgnored private let loadHasHistory: @Sendable () async -> Bool
    @ObservationIgnored private let loadProductsClosure: @Sendable () async -> [Product]
    @ObservationIgnored private let sync: @Sendable () async throws -> Void
    @ObservationIgnored private let transactionUpdates: @Sendable () -> AsyncStream<Void>
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    /// Creates a store for the entitlement granted by `productIDs`, seeding ``state`` from the
    /// last-known-good cache so an offline launch is correct before any StoreKit call returns.
    ///
    /// Every StoreKit interaction is an injectable closure defaulting to the real StoreKit 2 call,
    /// so production needs no arguments beyond `productIDs`, while tests inject fakes and stay
    /// deterministic. The initializer performs no StoreKit work and starts no tasks — call
    /// ``start()`` (or the individual methods) to reach the network.
    ///
    /// ```swift
    /// // Production: defaults talk to real StoreKit.
    /// let store = EntitlementStore(productIDs: ["com.app.pro.lifetime", "com.app.pro.monthly"])
    /// await store.start()   // load products, resolve entitlement, observe updates
    /// ```
    ///
    /// - Parameters:
    ///   - productIDs: The identifiers that grant the entitlement (passed to ``EntitlementEngine``).
    ///   - defaults: Backing store for the last-known-good cache. Defaults to `.standard`; inject a
    ///     suite in tests.
    ///   - cacheKey: `UserDefaults` key for the cached facts. Defaults to a namespaced key; override
    ///     if an app manages more than one entitlement.
    ///   - schemaVersion: Cache schema version; bump to invalidate every cached entry after a shape
    ///     change. Defaults to `1`.
    ///   - now: Current-time source for expiry checks. Defaults to `Date()`; inject a fixed clock in
    ///     tests.
    ///   - loadFacts: Fetches the current entitling facts. Defaults to reading
    ///     `Transaction.currentEntitlements` and mapping the ones in `productIDs`.
    ///   - loadHasHistory: Reports whether any purchase history for `productIDs` is visible — the
    ///     positive evidence that lets an empty result revoke a cached grant. Defaults to scanning
    ///     `Transaction.all`.
    ///   - loadProducts: Loads `Product` metadata. Defaults to `Product.products(for:)`.
    ///   - sync: Restores purchases from the App Store. Defaults to `AppStore.sync()`.
    ///   - transactionUpdates: A stream that emits once per external transaction change (renewals,
    ///     Ask-to-Buy approvals, refunds, purchases on another device). Defaults to bridging
    ///     `Transaction.updates`, finishing each verified transaction.
    public init(
        productIDs: Set<String>,
        defaults: UserDefaults = .standard,
        cacheKey: String = "baseplate.storekit.entitlement",
        schemaVersion: Int = 1,
        now: @escaping @Sendable () -> Date = { Date() },
        loadFacts: (@Sendable () async -> [TransactionFact])? = nil,
        loadHasHistory: (@Sendable () async -> Bool)? = nil,
        loadProducts: (@Sendable () async -> [Product])? = nil,
        sync: @escaping @Sendable () async throws -> Void = { try await AppStore.sync() },
        transactionUpdates: (@Sendable () -> AsyncStream<Void>)? = nil
    ) {
        let cache = CodableDefaultsStore<[TransactionFact]>(
            key: cacheKey, schemaVersion: schemaVersion, defaults: defaults, now: now)
        self.engine = EntitlementEngine(productIDs: productIDs)
        self.cache = cache
        self.now = now
        self.loadFacts = loadFacts ?? EntitlementStore.liveFacts(productIDs: productIDs)
        self.loadHasHistory =
            loadHasHistory ?? EntitlementStore.liveHasHistory(productIDs: productIDs)
        self.loadProductsClosure =
            loadProducts ?? EntitlementStore.liveProducts(productIDs: productIDs)
        self.sync = sync
        self.transactionUpdates = transactionUpdates ?? EntitlementStore.liveUpdates()
        self.facts = cache.load() ?? []
    }

    deinit { updatesTask?.cancel() }

    /// The current entitlement state, derived from ``facts`` at the current time.
    ///
    /// ```swift
    /// if store.state == .expired { /* show a resubscribe prompt */ }
    /// ```
    public var state: EntitlementState { engine.evaluate(facts: facts, now: now()) }

    /// Whether the entitlement is currently active — the single flag a feature gate reads.
    ///
    /// ```swift
    /// exportButton.isEnabled = store.hasEntitlement
    /// ```
    public var hasEntitlement: Bool { state.isActive }

    /// Whether a specific product currently entitles the user (active and non-revoked).
    ///
    /// Useful when several products grant the same entitlement but the UI wants to know which the
    /// user actually holds (e.g. to show "Lifetime" vs "Monthly").
    ///
    /// ```swift
    /// if store.isEntitled("com.app.pro.lifetime") { /* badge as a lifetime owner */ }
    /// ```
    ///
    /// - Parameter productID: The product identifier to check.
    /// - Returns: `true` when a known fact for `productID` is active right now.
    public func isEntitled(_ productID: String) -> Bool {
        facts.contains { $0.productID == productID && $0.isActive(at: now()) }
    }

    /// Loads products, resolves the entitlement once, and begins observing transaction updates.
    ///
    /// Call once at launch. Safe to call again — observation is only started once. On a fresh
    /// install with no network, ``state`` still reflects the cached last-known-good until StoreKit
    /// responds.
    ///
    /// ```swift
    /// let store = EntitlementStore(productIDs: ["com.app.pro"])
    /// await store.start()
    /// ```
    public func start() async {
        await loadProductInfo()
        await refresh()
        observeUpdates()
    }

    /// Loads `Product` metadata into ``products`` for the paywall's localized display.
    ///
    /// ```swift
    /// await store.loadProductInfo()
    /// for product in store.products { print(product.displayName, product.displayPrice) }
    /// ```
    public func loadProductInfo() async {
        products = await loadProductsClosure()
    }

    /// Re-resolves the entitlement from StoreKit and persists the result as the new last-known-good.
    ///
    /// Fetches the live facts; if there are none, asks whether any purchase history is visible. The
    /// pure ``EntitlementEngine/reconcile(live:cached:hasPurchaseHistory:now:)`` then decides
    /// whether to adopt the (possibly empty) live facts or keep the cached grant — so an offline or
    /// unsynced launch never revokes a paying customer, while a genuine refund or lapse does
    /// downgrade. The adopted facts are cached and ``facts`` updated.
    ///
    /// ```swift
    /// let resolved = await store.refresh()
    /// print(resolved)   // entitled / expired / notEntitled
    /// ```
    ///
    /// - Returns: The freshly-resolved ``EntitlementState``.
    @discardableResult
    public func refresh() async -> EntitlementState {
        let live = await loadFacts()
        let hasHistory = live.isEmpty ? await loadHasHistory() : true
        let adopted = engine.reconcile(
            live: live, cached: facts, hasPurchaseHistory: hasHistory, now: now())
        facts = adopted
        cache.save(adopted)
        return engine.evaluate(facts: adopted, now: now())
    }

    /// Restores purchases (an App Store sync) then re-resolves the entitlement.
    ///
    /// Back the paywall's "Restore Purchases" button with this. The sync is best-effort — it also
    /// throws when the user cancels the sign-in sheet — so a failure is swallowed and the
    /// entitlement is re-checked regardless, since a cached or already-synced entitlement can
    /// satisfy the restore on its own.
    ///
    /// ```swift
    /// let state = await store.restore()
    /// if !state.isActive { /* "Nothing to restore" */ }
    /// ```
    ///
    /// - Returns: The ``EntitlementState`` after the sync and refresh.
    @discardableResult
    public func restore() async -> EntitlementState {
        try? await sync()
        return await refresh()
    }

    /// Starts the background task that refreshes on every external transaction change. Idempotent.
    ///
    /// Called by ``start()``; exposed separately for callers that resolve the entitlement on their
    /// own schedule but still want live renewals/refunds reflected. Cancelled automatically on
    /// deinit.
    public func observeUpdates() {
        guard updatesTask == nil else { return }
        let stream = transactionUpdates()
        updatesTask = Task { [weak self] in
            for await _ in stream {
                await self?.refresh()
            }
        }
    }

    // MARK: - Live StoreKit closures (the injected defaults)

    /// Reads live entitlement facts from StoreKit, combining two sources so the engine can tell an
    /// *expired* subscription apart from a *never-purchased* one.
    ///
    /// - `Transaction.currentEntitlements` gives the products currently in force — active subs,
    ///   lifetime unlocks, and subs in billing grace/retry. These are emitted as **active** facts
    ///   (no expiry), so a grace-period subscriber is never mis-reported as expired.
    /// - For any product *not* currently in force, `Transaction.latest(for:)` surfaces its most
    ///   recent transaction: a lapsed subscription (past `expirationDate` ⇒ `.expired`) or a
    ///   refunded purchase (`revocationDate` ⇒ `.notEntitled`). `currentEntitlements` deliberately
    ///   excludes fully-expired subscriptions, so without this a lapsed subscriber would collapse to
    ///   `.notEntitled` and the `.expired` win-back state would be unreachable.
    ///
    /// Both calls read the on-device transaction store, so this works offline for previously-synced
    /// transactions.
    private static func liveFacts(
        productIDs: Set<String>
    ) -> @Sendable () async -> [TransactionFact] {
        {
            var facts: [TransactionFact] = []
            var inForce: Set<String> = []
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result,
                    productIDs.contains(transaction.productID)
                else { continue }
                inForce.insert(transaction.productID)
                // In force (incl. grace/billing-retry) ⇒ active regardless of the raw expiry date.
                facts.append(
                    TransactionFact(
                        productID: transaction.productID,
                        isRevoked: transaction.revocationDate != nil,
                        expirationDate: transaction.revocationDate != nil
                            ? transaction.expirationDate : nil))
            }
            // Surface lapsed / refunded transactions for products no longer in force, so the engine
            // can return .expired rather than silently discarding a cached grant.
            for productID in productIDs where !inForce.contains(productID) {
                if case .verified(let transaction)? = await Transaction.latest(for: productID) {
                    facts.append(
                        TransactionFact(
                            productID: productID,
                            isRevoked: transaction.revocationDate != nil,
                            expirationDate: transaction.expirationDate
                                ?? Date(timeIntervalSince1970: 0)))
                }
            }
            return facts
        }
    }

    /// True when any transaction (current, expired, or revoked) for `productIDs` is on record — the
    /// positive evidence that a "not entitled" result can be believed rather than a cold database.
    private static func liveHasHistory(productIDs: Set<String>) -> @Sendable () async -> Bool {
        {
            for await result in Transaction.all {
                if case .verified(let transaction) = result,
                    productIDs.contains(transaction.productID)
                {
                    return true
                }
            }
            return false
        }
    }

    /// Loads product metadata, tolerating a failure as an empty list (offline / transient).
    private static func liveProducts(productIDs: Set<String>) -> @Sendable () async -> [Product] {
        { (try? await Product.products(for: Array(productIDs))) ?? [] }
    }

    /// Bridges `Transaction.updates` to a plain change signal, finishing each verified transaction.
    private static func liveUpdates() -> @Sendable () -> AsyncStream<Void> {
        {
            AsyncStream { continuation in
                let task = Task {
                    for await update in Transaction.updates {
                        if case .verified(let transaction) = update {
                            await transaction.finish()
                        }
                        continuation.yield(())
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    }
}
