import Foundation

/// The persisted on/off preference for haptic feedback, with a first-launch default of *on*.
///
/// This is the pure, portable decision layer behind ``Haptics`` — it owns only the question "should
/// haptics fire?" and its persistence, with no UIKit dependency, so the gating logic is testable on
/// every platform. The `UserDefaults` store is injected, so tests use an in-memory suite. The
/// first-launch subtlety it encapsulates: a plain `bool(forKey:)` reads a missing key as `false`,
/// which would silently ship haptics *off*; this type checks for key absence and defaults to `true`.
///
/// ```swift
/// import Foundation
///
/// let defaults = UserDefaults(suiteName: "example")!
/// let pref = HapticsPreference(defaults: defaults)
/// print(pref.isEnabled)   // true — default on for a fresh install
/// pref.setEnabled(false)
/// print(pref.isEnabled)   // false
/// ```
public struct HapticsPreference: @unchecked Sendable {
    // @unchecked Sendable: the only stored reference type is `UserDefaults`, which Apple documents
    // as thread-safe but does not annotate `Sendable`; `key` is a value type.
    private let defaults: UserDefaults
    private let key: String

    /// Creates a preference backed by a `UserDefaults` store and key.
    ///
    /// ```swift
    /// import Foundation
    ///
    /// let pref = HapticsPreference(defaults: .standard, key: "MyApp.hapticsEnabled")
    /// _ = pref
    /// ```
    ///
    /// - Parameters:
    ///   - defaults: The backing store. Defaults to `.standard`; inject a suite in tests.
    ///   - key: The `UserDefaults` key under which the flag is stored. Defaults to
    ///     `"BaseplateHapticsEnabled"`.
    public init(defaults: UserDefaults = .standard, key: String = "BaseplateHapticsEnabled") {
        self.defaults = defaults
        self.key = key
    }

    /// Whether haptic feedback should fire.
    ///
    /// Returns `true` when nothing has been stored yet (fresh install), otherwise the stored flag.
    ///
    /// ```swift
    /// import Foundation
    ///
    /// let pref = HapticsPreference(defaults: UserDefaults(suiteName: "example2")!)
    /// print(pref.isEnabled)   // true
    /// ```
    public var isEnabled: Bool {
        guard defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }

    /// Persists whether haptic feedback should fire.
    ///
    /// ```swift
    /// import Foundation
    ///
    /// let pref = HapticsPreference(defaults: UserDefaults(suiteName: "example3")!)
    /// pref.setEnabled(false)
    /// print(pref.isEnabled)   // false
    /// ```
    ///
    /// - Parameter enabled: `true` to allow haptics, `false` to suppress them.
    public func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: key)
    }
}
