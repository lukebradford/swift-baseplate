import Foundation

/// Decides whether to show "what's new" release notes once per marketing version.
///
/// Built directly on ``VersionChange``: release notes belong on an **upgrade**, exactly once for
/// that version, and — by default — should not greet a brand-new user on a fresh install (they have
/// nothing to catch up on). ``shouldShowWhatsNew`` reads that decision from the stored version
/// baseline; ``markShown()`` advances the baseline to the current version.
///
/// ### Usage contract
/// Call ``markShown()`` **once per launch** after you have handled what's-new — including launches
/// where nothing was presented — so the baseline always advances to the running version. That is
/// what lets a fresh install (skipped) still see the notes on its *next* upgrade:
///
/// ```swift
/// let gate = WhatsNewGate(currentVersion: "1.3.0", defaults: .standard)
/// if gate.shouldShowWhatsNew {
///     // present the release-notes sheet …
/// }
/// gate.markShown()   // always, at the end of launch handling
/// ```
///
/// - Invariant: For a given `currentVersion`, ``shouldShowWhatsNew`` returns `true` at most once
///   across the life of the store (zero times on a fresh install unless `showOnFreshInstall` is
///   `true`), provided ``markShown()`` is called once per launch.
public struct WhatsNewGate: @unchecked Sendable {
    // @unchecked Sendable: the only reference-type field (inside `versionChange`) is `UserDefaults`,
    // documented thread-safe by Apple but not annotated `Sendable`; the rest are value types.

    /// The current marketing version whose notes may be shown.
    public let currentVersion: String

    /// Whether a fresh install (no prior version stored) should see the notes. Defaults to `false`.
    public let showOnFreshInstall: Bool

    private let versionChange: VersionChange

    /// Creates a what's-new gate.
    ///
    /// ```swift
    /// let gate = WhatsNewGate(currentVersion: "2.0.0", defaults: UserDefaults(suiteName: "t")!)
    /// ```
    ///
    /// - Parameters:
    ///   - currentVersion: The current marketing version.
    ///   - showOnFreshInstall: Show notes to first-time users too. Defaults to `false`.
    ///   - defaults: The backing store. Defaults to `.standard`; inject a suite in tests.
    ///   - key: The `UserDefaults` key for the version baseline. Defaults to
    ///     `"baseplate.whatsNew.lastShownVersion"`.
    public init(
        currentVersion: String,
        showOnFreshInstall: Bool = false,
        defaults: UserDefaults = .standard,
        key: String = "baseplate.whatsNew.lastShownVersion"
    ) {
        self.currentVersion = currentVersion
        self.showOnFreshInstall = showOnFreshInstall
        self.versionChange = VersionChange(
            currentVersion: currentVersion,
            defaults: defaults,
            key: key
        )
    }

    /// Whether this version's release notes should be shown now.
    ///
    /// `true` on an upgrade whose notes have not yet been marked shown; `false` when the version is
    /// unchanged or rolled back; and, on a fresh install, `true` only if ``showOnFreshInstall`` is
    /// set. Reading this does not mutate anything — advance the baseline with ``markShown()``.
    ///
    /// ```swift
    /// let suite = UserDefaults(suiteName: "t")!
    /// // an existing user who last ran 1.0.0:
    /// WhatsNewGate(currentVersion: "1.0.0", defaults: suite).markShown()
    /// let gate = WhatsNewGate(currentVersion: "1.1.0", defaults: suite)
    /// print(gate.shouldShowWhatsNew)   // true
    /// ```
    public var shouldShowWhatsNew: Bool {
        switch versionChange.transition {
        case .freshInstall: return showOnFreshInstall
        case .upgrade: return true
        case .downgrade, .unchanged: return false
        }
    }

    /// Advances the stored version baseline to ``currentVersion``.
    ///
    /// Call once per launch after handling what's-new (presented or not), so the next launch of a
    /// *newer* version is recognized as an upgrade. After this, ``shouldShowWhatsNew`` is `false`
    /// for ``currentVersion``.
    ///
    /// ```swift
    /// let gate = WhatsNewGate(currentVersion: "1.1.0", defaults: UserDefaults(suiteName: "t")!)
    /// gate.markShown()
    /// print(gate.shouldShowWhatsNew)   // false
    /// ```
    public func markShown() {
        versionChange.commit()
    }
}
