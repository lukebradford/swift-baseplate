import Foundation

/// Detects whether this is the app's first-ever launch and lets you consume that fact once.
///
/// A tiny, injectable wrapper over a single `UserDefaults` boolean, so onboarding, first-run
/// defaults, and "welcome" screens have one deterministic source of truth instead of scattered
/// ad-hoc flags. ``isFirstLaunch`` reflects the stored flag without changing it; ``markLaunched()``
/// records that the app has now run at least once; ``consume()`` combines the two so the first-run
/// path fires exactly once.
///
/// ```swift
/// let suite = UserDefaults(suiteName: "example")!
/// let firstLaunch = FirstLaunch(defaults: suite)
/// if firstLaunch.consume() {
///     // seed defaults, show onboarding — runs only the very first time
/// }
/// print(firstLaunch.isFirstLaunch)   // false, after consume()
/// ```
///
/// - Invariant: After ``markLaunched()`` (or a `true` result from ``consume()``), ``isFirstLaunch``
///   is `false` for the life of the store.
public struct FirstLaunch: @unchecked Sendable {
    // @unchecked Sendable: the only reference-type field is `UserDefaults`, documented thread-safe
    // by Apple but not annotated `Sendable`; the remaining field is a value type.

    private let defaults: UserDefaults
    private let key: String

    /// Creates a first-launch detector.
    ///
    /// ```swift
    /// let firstLaunch = FirstLaunch(defaults: UserDefaults(suiteName: "t")!)
    /// ```
    ///
    /// - Parameters:
    ///   - defaults: The backing store. Defaults to `.standard`; inject an in-memory suite in tests.
    ///   - key: The `UserDefaults` key for the "has launched" flag. Defaults to
    ///     `"baseplate.firstLaunch.hasLaunched"`.
    public init(
        defaults: UserDefaults = .standard,
        key: String = "baseplate.firstLaunch.hasLaunched"
    ) {
        self.defaults = defaults
        self.key = key
    }

    /// `true` until ``markLaunched()`` (or a successful ``consume()``) has ever run.
    ///
    /// Reading this does not change any state, so it is safe to check repeatedly.
    ///
    /// ```swift
    /// let firstLaunch = FirstLaunch(defaults: UserDefaults(suiteName: "t")!)
    /// print(firstLaunch.isFirstLaunch)   // true, on a clean store
    /// ```
    public var isFirstLaunch: Bool { !defaults.bool(forKey: key) }

    /// Records that the app has now launched, so ``isFirstLaunch`` becomes `false`.
    ///
    /// Idempotent — calling it again has no further effect.
    ///
    /// ```swift
    /// let firstLaunch = FirstLaunch(defaults: UserDefaults(suiteName: "t")!)
    /// firstLaunch.markLaunched()
    /// print(firstLaunch.isFirstLaunch)   // false
    /// ```
    public func markLaunched() {
        defaults.set(true, forKey: key)
    }

    /// Returns whether this is the first launch and, if so, marks it consumed in one step.
    ///
    /// Use this to guard a one-time first-run path: it returns `true` exactly once, then `false`
    /// forever after.
    ///
    /// ```swift
    /// let firstLaunch = FirstLaunch(defaults: UserDefaults(suiteName: "t")!)
    /// print(firstLaunch.consume())   // true
    /// print(firstLaunch.consume())   // false
    /// ```
    ///
    /// - Returns: `true` on the first call against a clean store, `false` on every call after.
    /// - Note: The check-and-mark is not atomic across isolation domains. Call `consume()` from a
    ///   single domain (typically the main actor); two truly-concurrent first calls could each see a
    ///   clean store and both return `true`. This holds for the intended once-at-launch use.
    @discardableResult
    public func consume() -> Bool {
        guard isFirstLaunch else { return false }
        markLaunched()
        return true
    }
}
