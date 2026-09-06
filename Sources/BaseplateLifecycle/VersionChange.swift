import Foundation

/// Classifies how the app's version has changed since it last ran — fresh install, upgrade,
/// downgrade, or unchanged — against a version string stored in `UserDefaults`.
///
/// This is the primitive under "run migrations on upgrade", "show what's new after an update", and
/// "reset a cache when the build changes". It reads the last-seen version, compares it to the
/// current one, and — when you call ``commit()`` — writes the current version back so the next
/// launch sees the new baseline. The comparison itself is a pure string equality (a version is
/// "changed" iff its string differs), exposed as ``classify(current:lastSeen:)`` for testing;
/// ordering upgrade-vs-downgrade uses a numeric dotted-component compare.
///
/// ```swift
/// let suite = UserDefaults(suiteName: "example")!
/// let tracker = VersionChange(currentVersion: "1.2.0", defaults: suite)
/// switch tracker.transition {
/// case .freshInstall:            break   // first ever run
/// case .upgrade(let from, _):    print("upgraded from \(from)")
/// case .downgrade, .unchanged:   break
/// }
/// tracker.commit()   // persist "1.2.0" as the new last-seen version
/// ```
///
/// - Invariant: After ``commit()``, ``transition`` reports ``Transition/unchanged(_:)`` for the
///   same `currentVersion` until a different version is constructed.
public struct VersionChange: @unchecked Sendable {
    // @unchecked Sendable: the only reference-type field is `UserDefaults`, documented thread-safe
    // by Apple but not annotated `Sendable`; every other field is a value type.

    /// How the current version relates to the last-seen one.
    public enum Transition: Sendable, Equatable {
        /// No version was stored — a clean install (or a wiped store).
        case freshInstall
        /// The current version is newer than the stored one.
        case upgrade(from: String, to: String)
        /// The current version is older than the stored one (a rollback or restore).
        case downgrade(from: String, to: String)
        /// The current version equals the stored one.
        case unchanged(String)
    }

    /// The marketing (or build) version considered "current".
    public let currentVersion: String

    private let defaults: UserDefaults
    private let key: String

    /// Creates a version-change tracker.
    ///
    /// ```swift
    /// let tracker = VersionChange(currentVersion: "2.0.0", defaults: UserDefaults(suiteName: "t")!)
    /// ```
    ///
    /// - Parameters:
    ///   - currentVersion: The current version string (e.g. `"1.4.0"` or a build number).
    ///   - defaults: The backing store. Defaults to `.standard`; inject a suite in tests.
    ///   - key: The `UserDefaults` key holding the last-seen version. Defaults to
    ///     `"baseplate.version.lastSeen"`.
    public init(
        currentVersion: String,
        defaults: UserDefaults = .standard,
        key: String = "baseplate.version.lastSeen"
    ) {
        self.currentVersion = currentVersion
        self.defaults = defaults
        self.key = key
    }

    /// The last version stored by ``commit()``, or `nil` if none has been.
    public var lastSeenVersion: String? { defaults.string(forKey: key) }

    /// How ``currentVersion`` relates to ``lastSeenVersion`` right now.
    ///
    /// Reading this does not persist anything; call ``commit()`` to update the baseline.
    ///
    /// ```swift
    /// let tracker = VersionChange(currentVersion: "1.0.0", defaults: UserDefaults(suiteName: "t")!)
    /// print(tracker.transition)   // freshInstall
    /// ```
    public var transition: Transition {
        Self.classify(current: currentVersion, lastSeen: lastSeenVersion)
    }

    /// Persists ``currentVersion`` as the new last-seen version.
    ///
    /// Call this once you have handled the transition (ran migrations, shown release notes) so the
    /// next launch compares against this version.
    ///
    /// ```swift
    /// let tracker = VersionChange(currentVersion: "1.1.0", defaults: UserDefaults(suiteName: "t")!)
    /// tracker.commit()
    /// print(tracker.lastSeenVersion!)   // "1.1.0"
    /// ```
    public func commit() {
        defaults.set(currentVersion, forKey: key)
    }

    /// The pure classification of `current` against `lastSeen`, free of any store.
    ///
    /// A `nil` `lastSeen` is a ``Transition/freshInstall``. Otherwise the two strings are compared
    /// numerically by dotted component (so `"1.10.0"` is newer than `"1.9.0"`); equal strings are
    /// ``Transition/unchanged(_:)``.
    ///
    /// ```swift
    /// print(VersionChange.classify(current: "1.2.0", lastSeen: "1.1.0"))
    /// // upgrade(from: "1.1.0", to: "1.2.0")
    /// ```
    ///
    /// - Parameters:
    ///   - current: The current version string.
    ///   - lastSeen: The previously stored version, or `nil` for a fresh install.
    /// - Returns: The matching ``Transition``.
    public static func classify(current: String, lastSeen: String?) -> Transition {
        guard let lastSeen else { return .freshInstall }
        switch compare(lastSeen, current) {
        case .orderedAscending: return .upgrade(from: lastSeen, to: current)
        case .orderedSame: return .unchanged(current)  // numerically equal (incl. "1.0" vs "1.0.0")
        case .orderedDescending: return .downgrade(from: lastSeen, to: current)
        }
    }

    /// Numeric dotted-component comparison: `"1.10"` > `"1.9"`, `"1.0"` == `"1.0.0"`.
    private static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }
}
