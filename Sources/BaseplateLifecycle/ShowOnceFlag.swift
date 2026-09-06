import Foundation

/// A one-shot flag for "show this exactly once" UI — either once *ever* or once *per app version*.
///
/// Use it for a tip callout, a migration notice, a rating nudge, or any banner that must not
/// reappear after it has been seen. ``shouldShow`` reports whether the thing is still pending;
/// ``markShown()`` records that it has been shown. With ``Scope/perVersion``, the flag re-arms
/// whenever ``currentVersion`` changes, so each release gets one fresh showing; with
/// ``Scope/ever`` it never re-arms.
///
/// ```swift
/// let suite = UserDefaults(suiteName: "example")!
/// let flag = ShowOnceFlag(key: "proTip", scope: .ever, defaults: suite)
/// if flag.shouldShow {
///     // present the tip …
///     flag.markShown()
/// }
/// print(flag.shouldShow)   // false
/// ```
///
/// - Invariant: For ``Scope/ever``, once ``markShown()`` is called ``shouldShow`` is `false`
///   forever. For ``Scope/perVersion``, ``shouldShow`` is `false` only while ``currentVersion``
///   matches the version marked.
public struct ShowOnceFlag: @unchecked Sendable {
    // @unchecked Sendable: the only reference-type field is `UserDefaults`, documented thread-safe
    // by Apple but not annotated `Sendable`; every other field is a value type.

    /// How often the flag re-arms.
    public enum Scope: Sendable, Equatable {
        /// Show once and never again, regardless of app version.
        case ever
        /// Show once per marketing version; a new version re-arms it.
        case perVersion
    }

    /// The scope controlling re-arming.
    public let scope: Scope

    /// The current app version, consulted only when ``scope`` is ``Scope/perVersion``.
    public let currentVersion: String

    private let defaults: UserDefaults
    private let key: String

    /// Creates a show-once flag.
    ///
    /// ```swift
    /// let flag = ShowOnceFlag(
    ///     key: "whatsNew", scope: .perVersion, currentVersion: "1.2.0",
    ///     defaults: UserDefaults(suiteName: "t")!)
    /// ```
    ///
    /// - Parameters:
    ///   - key: A stable identifier for this particular flag (namespaced internally).
    ///   - scope: Whether it shows once ever or once per version. Defaults to ``Scope/ever``.
    ///   - currentVersion: The current app version; used only for ``Scope/perVersion``. Defaults to
    ///     `""` (fine when `scope` is ``Scope/ever``).
    ///   - defaults: The backing store. Defaults to `.standard`; inject a suite in tests.
    public init(
        key: String,
        scope: Scope = .ever,
        currentVersion: String = "",
        defaults: UserDefaults = .standard
    ) {
        self.key = "baseplate.showOnce.\(key)"
        self.scope = scope
        self.currentVersion = currentVersion
        self.defaults = defaults
    }

    /// Whether the one-shot content is still pending display.
    ///
    /// ```swift
    /// let flag = ShowOnceFlag(key: "tip", defaults: UserDefaults(suiteName: "t")!)
    /// print(flag.shouldShow)   // true, on a clean store
    /// ```
    public var shouldShow: Bool {
        switch scope {
        case .ever:
            return !defaults.bool(forKey: key)
        case .perVersion:
            return defaults.string(forKey: key) != currentVersion
        }
    }

    /// Records that the content has been shown, so ``shouldShow`` becomes `false`.
    ///
    /// For ``Scope/perVersion`` this stores ``currentVersion``, so the flag re-arms on the next
    /// version. Idempotent within a version/scope.
    ///
    /// ```swift
    /// let flag = ShowOnceFlag(key: "tip", defaults: UserDefaults(suiteName: "t")!)
    /// flag.markShown()
    /// print(flag.shouldShow)   // false
    /// ```
    public func markShown() {
        switch scope {
        case .ever:
            defaults.set(true, forKey: key)
        case .perVersion:
            defaults.set(currentVersion, forKey: key)
        }
    }

    /// Clears the flag so ``shouldShow`` returns `true` again (mainly for tests and debug menus).
    ///
    /// ```swift
    /// let flag = ShowOnceFlag(key: "tip", defaults: UserDefaults(suiteName: "t")!)
    /// flag.markShown()
    /// flag.reset()
    /// print(flag.shouldShow)   // true
    /// ```
    public func reset() {
        defaults.removeObject(forKey: key)
    }
}
