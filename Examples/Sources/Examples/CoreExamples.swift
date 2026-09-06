import BaseplateCore
import Foundation

/// A tour of `BaseplateCore` — the dependency-free, portable foundation.
func coreExamples() {
    // Type-safe Keychain, survives reinstall, no dependency. String and Data convenience inits,
    // plus a Codable factory.
    let deviceID = KeychainItem<String>(service: "com.you.app", account: "deviceID")
    try? deviceID.set(UUID().uuidString)
    _ = try? deviceID.get()

    // Versioned, self-expiring, clock-skew-guarded Codable persistence.
    struct Draft: Codable & Sendable { var text: String }
    let store = CodableDefaultsStore<Draft>(
        key: "draft", schemaVersion: 2, maxAge: 60 * 60 * 24 * 30)  // expire after 30 days
    store.save(Draft(text: "hello"))
    _ = store.load()

    // A typed default with a first-class fallback.
    let defaults = UserDefaults(suiteName: "examples")!
    let launches = UserDefault(wrappedValue: 0, "launchCount", store: defaults)
    _ = launches.wrappedValue

    // Reproducible randomness for daily challenges & stable previews.
    let today = DailySeed()
    var rng = SeededRandomNumberGenerator(seed: today.seed)
    _ = [1, 2, 3, 4].randomElement(using: &rng)
    _ = today.isNewDayAvailable(since: .distantPast)

    // Correct, localized humanization (inject the reference date so output is deterministic).
    let now = Date(timeIntervalSince1970: 1_000_000)
    _ = Humanize.relativeDate(now.addingTimeInterval(-3600), relativeTo: now)  // "1 hour ago"
    _ = Humanize.byteCount(1_536_000)  // "1.5 MB"
    _ = Humanize.duration(90)  // "1 minute, 30 seconds"
    _ = Humanize.ordinal(3)  // "3rd"

    // Finder-style, numeric-aware ordering ("file2" < "file10").
    _ = NameOrdering.sortedByName(["file10", "file2", "file1"])

    // The one safe stdlib gap Baseplate fills (chunking/dedup belong to swift-algorithms).
    _ = [10, 20, 30][safe: 5]  // nil, not a crash
}
