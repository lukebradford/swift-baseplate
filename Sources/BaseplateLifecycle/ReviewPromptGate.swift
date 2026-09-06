import Foundation

/// Decides *when* to ask for an App Store review — the eligibility logic only, never the prompt.
///
/// A good review ask lands after the user has clearly gotten value from the app (a run of
/// "meaningful events" — a save, a share, a completed task) and never interrupts a brand-new user
/// on their first session. This gate encodes exactly that policy and nothing else:
///
/// - fires only after at least ``minimumEvents`` meaningful events have been recorded,
/// - fires **at most once per app version** (a new version re-arms it), and
/// - optionally waits ``minimumInterval`` seconds after the *first* meaningful event, so a burst of
///   events in the opening session cannot trigger a prompt on first launch.
///
/// Because the count and interval must both accrue over time, a genuinely first-launch user is
/// never asked. The gate is **presentation-agnostic**: when ``shouldRequestReview(appVersion:)``
/// returns `true`, the caller presents the request itself (SwiftUI's `requestReview` environment
/// action, or `SKStoreReviewController`) and then calls ``markRequested(appVersion:)``. Apple
/// applies its own throttle (three prompts per user per 365 days) on top of this, so a loose gate
/// cannot spam anyone.
///
/// All state lives in the injected `UserDefaults`; the pure decision is factored into the static
/// ``shouldRequest(meaningfulEvents:minimumEvents:firstEventDate:now:minimumInterval:lastRequestedVersion:appVersion:)``
/// so it can be tested without any store or clock.
///
/// ```swift
/// let gate = ReviewPromptGate(minimumEvents: 3)
/// gate.recordMeaningfulEvent()            // user saved something
/// gate.recordMeaningfulEvent()
/// gate.recordMeaningfulEvent()
/// if gate.shouldRequestReview(appVersion: "1.4.0") {
///     // present SKStoreReviewController / requestReview here …
///     gate.markRequested(appVersion: "1.4.0")
/// }
/// ```
///
/// - Invariant: Once ``markRequested(appVersion:)`` is called for a version,
///   ``shouldRequestReview(appVersion:)`` returns `false` for that same version forever.
/// - Note: The mutating methods (``recordMeaningfulEvent()``, ``markRequested(appVersion:)``) do a
///   non-atomic read-modify-write on `UserDefaults`. Call them from a single isolation domain
///   (typically the main actor, where app-lifecycle events naturally occur); concurrent calls from
///   different domains can lose an increment. Reads like ``shouldRequestReview(appVersion:)`` are safe.
public struct ReviewPromptGate: @unchecked Sendable {
    // @unchecked Sendable: the only reference-type field is `UserDefaults`, which Apple documents
    // as thread-safe but does not annotate `Sendable`; every other field is a value type or a
    // `@Sendable` closure. NOTE: individual UserDefaults accesses are thread-safe, but
    // `recordMeaningfulEvent()` performs a read-modify-write that is NOT atomic across isolation
    // domains — call the mutating methods from a single domain (see the type doc). This is safe for
    // the intended use (recording delight moments from the main actor) and keeps the value-type API.

    /// The number of meaningful events required before a prompt is ever eligible. Always `>= 1`.
    public let minimumEvents: Int

    /// If set, the minimum seconds that must elapse after the *first* meaningful event before a
    /// prompt is eligible. `nil` disables the time gate (count-and-version only).
    public let minimumInterval: TimeInterval?

    private let defaults: UserDefaults
    private let now: @Sendable () -> Date
    private let eventCountKey: String
    private let firstEventDateKey: String
    private let lastRequestedVersionKey: String

    /// Creates a review-prompt gate.
    ///
    /// ```swift
    /// let suite = UserDefaults(suiteName: "tests")!
    /// let gate = ReviewPromptGate(minimumEvents: 2, defaults: suite)
    /// ```
    ///
    /// - Parameters:
    ///   - minimumEvents: Meaningful events required before a prompt is eligible. Defaults to `3`.
    ///   - minimumInterval: Optional minimum seconds since the first meaningful event. Defaults to
    ///     `nil` (no time gate).
    ///   - defaults: The backing store. Defaults to `.standard`; inject an in-memory suite in tests.
    ///   - now: The clock, injected for deterministic tests. Defaults to `{ Date() }`.
    ///   - keyPrefix: Namespacing prefix for the three `UserDefaults` keys. Defaults to
    ///     `"baseplate.review"`.
    /// - Precondition: `minimumEvents >= 1`.
    public init(
        minimumEvents: Int = 3,
        minimumInterval: TimeInterval? = nil,
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() },
        keyPrefix: String = "baseplate.review"
    ) {
        precondition(minimumEvents >= 1, "minimumEvents must be >= 1")
        self.minimumEvents = minimumEvents
        self.minimumInterval = minimumInterval
        self.defaults = defaults
        self.now = now
        self.eventCountKey = "\(keyPrefix).meaningfulEventCount"
        self.firstEventDateKey = "\(keyPrefix).firstEventDate"
        self.lastRequestedVersionKey = "\(keyPrefix).lastRequestedVersion"
    }

    /// The number of meaningful events recorded so far.
    ///
    /// ```swift
    /// let gate = ReviewPromptGate(defaults: UserDefaults(suiteName: "t")!)
    /// gate.recordMeaningfulEvent()
    /// print(gate.meaningfulEventCount)   // 1
    /// ```
    public var meaningfulEventCount: Int { defaults.integer(forKey: eventCountKey) }

    /// Records one meaningful event (a save, a share, a completed task) toward the threshold.
    ///
    /// The first call also stamps the "first event" date used by ``minimumInterval``. Call this at
    /// genuine success moments, not on every screen view.
    ///
    /// ```swift
    /// let gate = ReviewPromptGate(defaults: UserDefaults(suiteName: "t")!)
    /// gate.recordMeaningfulEvent()
    /// ```
    public func recordMeaningfulEvent() {
        defaults.set(meaningfulEventCount + 1, forKey: eventCountKey)
        if defaults.object(forKey: firstEventDateKey) == nil {
            defaults.set(now(), forKey: firstEventDateKey)
        }
    }

    /// Whether now is an appropriate moment to ask for a review on `appVersion`.
    ///
    /// Returns `true` only when the event count has reached ``minimumEvents``, the optional
    /// ``minimumInterval`` has elapsed since the first event, and no prompt has yet been marked for
    /// `appVersion`. This method does **not** consume anything — the caller presents the prompt and
    /// then calls ``markRequested(appVersion:)``.
    ///
    /// ```swift
    /// let gate = ReviewPromptGate(minimumEvents: 1, defaults: UserDefaults(suiteName: "t")!)
    /// gate.recordMeaningfulEvent()
    /// print(gate.shouldRequestReview(appVersion: "1.0.0"))   // true
    /// ```
    ///
    /// - Parameter appVersion: The current marketing version; a prompt fires at most once per value.
    /// - Returns: `true` at most once per version, and only after the thresholds are met.
    public func shouldRequestReview(appVersion: String) -> Bool {
        let firstEventDate = defaults.object(forKey: firstEventDateKey) as? Date
        return Self.shouldRequest(
            meaningfulEvents: meaningfulEventCount,
            minimumEvents: minimumEvents,
            firstEventDate: firstEventDate,
            now: now(),
            minimumInterval: minimumInterval,
            lastRequestedVersion: defaults.string(forKey: lastRequestedVersionKey),
            appVersion: appVersion
        )
    }

    /// Records that a review was requested for `appVersion`, so it is not asked again this version.
    ///
    /// Call this only after actually invoking the system prompt. This stores an upper bound on
    /// prompts *asked*, never a count of prompts *shown* — Apple may suppress its own dialog.
    ///
    /// ```swift
    /// let gate = ReviewPromptGate(defaults: UserDefaults(suiteName: "t")!)
    /// gate.markRequested(appVersion: "1.4.0")
    /// print(gate.shouldRequestReview(appVersion: "1.4.0"))   // false
    /// ```
    ///
    /// - Parameter appVersion: The version the prompt was shown for.
    public func markRequested(appVersion: String) {
        defaults.set(appVersion, forKey: lastRequestedVersionKey)
    }

    /// The pure eligibility decision, free of `UserDefaults` and the wall clock.
    ///
    /// Factored out so the policy can be exhaustively unit-tested. A `firstEventDate` in the future
    /// relative to `now` (a clock moved backward) yields a negative elapsed time and therefore
    /// fails the interval gate rather than passing it spuriously.
    ///
    /// ```swift
    /// let ok = ReviewPromptGate.shouldRequest(
    ///     meaningfulEvents: 3, minimumEvents: 3, firstEventDate: nil, now: Date(),
    ///     minimumInterval: nil, lastRequestedVersion: nil, appVersion: "2.0")
    /// print(ok)   // true
    /// ```
    ///
    /// - Parameters:
    ///   - meaningfulEvents: Events recorded so far.
    ///   - minimumEvents: Events required.
    ///   - firstEventDate: When the first event was recorded, or `nil` if none yet.
    ///   - now: The current instant.
    ///   - minimumInterval: Required seconds since `firstEventDate`, or `nil` to skip the time gate.
    ///   - lastRequestedVersion: The version last asked on, or `nil` if never.
    ///   - appVersion: The current version.
    /// - Returns: `true` when every gate passes.
    public static func shouldRequest(
        meaningfulEvents: Int,
        minimumEvents: Int,
        firstEventDate: Date?,
        now: Date,
        minimumInterval: TimeInterval?,
        lastRequestedVersion: String?,
        appVersion: String
    ) -> Bool {
        guard meaningfulEvents >= minimumEvents else { return false }
        guard lastRequestedVersion != appVersion else { return false }
        if let minimumInterval {
            guard let firstEventDate else { return false }
            guard now.timeIntervalSince(firstEventDate) >= minimumInterval else { return false }
        }
        return true
    }
}
