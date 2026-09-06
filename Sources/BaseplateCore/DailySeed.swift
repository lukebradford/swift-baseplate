import Foundation

/// Computes a stable "which day is it?" index and gates work to at most once per calendar day.
///
/// Two jobs, both anchored to an injectable clock and time zone so they are deterministic in
/// tests and identical for every user worldwide when anchored to UTC (the default):
///
/// 1. ``dayIndex`` — the number of whole calendar days since the Unix epoch, a small integer that
///    changes exactly once per day. Feed it to ``SeededRandomNumberGenerator`` (via ``seed``) to
///    give everyone the same "daily" content, or persist it to detect a day boundary.
/// 2. ``isNewDayAvailable(since:)`` — given the last time something ran, answers whether a fresh
///    day has begun, so a daily reward / daily puzzle / daily refresh fires once and only once.
///
/// - Invariant: the index is monotonic in real time for a fixed time zone — a later date never has
///   a smaller index — so a clock that jumps *backward* across a day boundary reports "no new day",
///   never a spurious one.
///
/// ```swift
/// let fixed = ISO8601DateFormatter().date(from: "2026-09-06T12:00:00Z")!
/// let daily = DailySeed(now: { fixed })   // UTC by default
/// var rng = SeededRandomNumberGenerator(seed: daily.seed)
/// print(daily.isNewDayAvailable(since: fixed.addingTimeInterval(-86_400)))   // true
/// print(Int.random(in: 0..<3, using: &rng))
/// ```
public struct DailySeed: Sendable {

    private let now: @Sendable () -> Date
    private let calendar: Calendar

    /// Creates a daily-seed source anchored to a clock and time zone.
    ///
    /// ```swift
    /// // Local-day semantics instead of the UTC default:
    /// let daily = DailySeed(timeZone: .current)
    /// print(daily.dayIndex >= 0)   // true
    /// ```
    ///
    /// - Parameters:
    ///   - now: The current-time source. Inject a fixed date in tests; defaults to `Date()`.
    ///   - timeZone: The time zone whose midnights delimit a "day". Defaults to UTC so all users
    ///     roll over simultaneously. Pass `.current` for device-local day boundaries.
    public init(
        now: @escaping @Sendable () -> Date = { Date() },
        timeZone: TimeZone = TimeZone(identifier: "UTC") ?? .gmt
    ) {
        self.now = now
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    /// The whole-day index for "now": days elapsed since 1970-01-01 in the configured time zone.
    ///
    /// ```swift
    /// let daily = DailySeed(now: { Date(timeIntervalSince1970: 0) })
    /// print(daily.dayIndex)   // 0
    /// ```
    public var dayIndex: Int {
        dayIndex(for: now())
    }

    /// The whole-day index for an arbitrary date, in the configured time zone.
    ///
    /// ```swift
    /// let daily = DailySeed()
    /// let a = daily.dayIndex(for: Date(timeIntervalSince1970: 0))
    /// let b = daily.dayIndex(for: Date(timeIntervalSince1970: 86_400))
    /// print(b - a)   // 1
    /// ```
    ///
    /// - Parameter date: The date to bucket into a day.
    /// - Returns: Days between the epoch's local midnight and `date`'s local midnight. Negative for
    ///   dates before 1970.
    public func dayIndex(for date: Date) -> Int {
        let epochStart = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        let dateStart = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: epochStart, to: dateStart).day ?? 0
    }

    /// A well-scrambled 64-bit seed derived from ``dayIndex``, ready to hand straight to an RNG.
    ///
    /// A raw day index is a small, low-entropy number, and feeding it *directly* to a bit-shift
    /// generator like ``SeededRandomNumberGenerator`` produces a badly-distributed first draw — the
    /// high bits (which `random(in:)` samples) stay near-constant across adjacent days, so a "daily"
    /// pick would barely change. This property therefore diffuses the day index through one
    /// ``SplitMix64Generator`` step first, so `SeededRandomNumberGenerator(seed: daily.seed)` gives a
    /// varied, high-quality stream from the very first value. It is still a pure function of the day.
    ///
    /// ```swift
    /// let daily = DailySeed(now: { Date(timeIntervalSince1970: 0) })
    /// var rng = SeededRandomNumberGenerator(seed: daily.seed)
    /// print(Int.random(in: 0..<100, using: &rng) >= 0)   // true — and it varies day to day
    /// ```
    ///
    /// - Returns: A diffused 64-bit seed. Deterministic: the same day always yields the same seed.
    public var seed: UInt64 {
        var mixer = SplitMix64Generator(seed: UInt64(bitPattern: Int64(dayIndex)))
        return mixer.next()
    }

    /// Reports whether "now" falls on a later day than `lastRun` — i.e. a new day is available.
    ///
    /// Use it to gate once-per-day work: compare against the persisted timestamp of the last run,
    /// and if it returns `true`, do the work and store the new timestamp.
    ///
    /// ```swift
    /// let now = Date(timeIntervalSince1970: 100_000)      // day 1
    /// let daily = DailySeed(now: { now })
    /// print(daily.isNewDayAvailable(since: Date(timeIntervalSince1970: 0)))       // true  (day 0)
    /// print(daily.isNewDayAvailable(since: now))                                  // false (same day)
    /// print(daily.isNewDayAvailable(since: Date(timeIntervalSince1970: 200_000))) // false (future)
    /// ```
    ///
    /// - Parameter lastRun: When the gated work last happened.
    /// - Returns: `true` iff "now" is on a strictly later calendar day than `lastRun`. A `lastRun`
    ///   in the future (device clock moved backward) returns `false`.
    public func isNewDayAvailable(since lastRun: Date) -> Bool {
        dayIndex(for: lastRun) < dayIndex
    }
}
