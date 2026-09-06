import BaseplateStoreKit
import Foundation

/// A tour of `BaseplateStoreKit` — testable StoreKit 2 for the no-backend indie.
func storeKitExamples() {
    // The PURE engine is where the real test coverage lives: entitlement state is a deterministic
    // function of transaction facts + the current date — no StoreKit runtime required.
    let engine = EntitlementEngine(productIDs: ["com.you.app.pro"])
    let facts = [TransactionFact(productID: "com.you.app.pro")]  // an active, non-expiring purchase
    _ = engine.evaluate(facts: facts, now: Date(timeIntervalSince1970: 1_000_000))  // .entitled

    // Grandfather a paid feature to anyone who bought before a cutoff version.
    _ = Grandfather.isGrandfathered(originalAppVersion: "1.2.0", boughtBefore: "2.0.0")  // true
}

/// The live layer. Shown for compilation only — not run here (it observes real transactions).
@MainActor
func storeKitLiveExample() async {
    let entitlements = EntitlementStore(productIDs: ["com.you.app.pro"])
    await entitlements.start()  // load products, observe Transaction.updates, cache LKG
    _ = entitlements.isEntitled("com.you.app.pro")
    _ = await entitlements.restore()
}
