import Foundation
import Testing

@testable import BaseplateCore

@Suite struct DailySeedTests {

    @Test func epoch_is_day_zero() {
        let daily = DailySeed(now: { Date(timeIntervalSince1970: 0) })
        #expect(daily.dayIndex == 0)
    }

    @Test func index_advances_once_per_utc_day() {
        let daily = DailySeed()
        let day0 = daily.dayIndex(for: Date(timeIntervalSince1970: 0))
        let day1 = daily.dayIndex(for: Date(timeIntervalSince1970: 86_400))
        let day1LateNight = daily.dayIndex(for: Date(timeIntervalSince1970: 86_400 + 86_399))
        #expect(day1 - day0 == 1)
        #expect(day1LateNight == day1)  // still the same day until the next midnight
    }

    @Test func seed_is_deterministic_per_day() {
        // Same day → same seed, always (so "daily" content is stable within the day).
        let a = DailySeed(now: { Date(timeIntervalSince1970: 5 * 86_400) }).seed
        let b = DailySeed(now: { Date(timeIntervalSince1970: 5 * 86_400 + 3600) }).seed
        #expect(a == b)
    }

    @Test func seed_differs_and_draws_vary_across_adjacent_days() {
        // Regression guard: a raw day-index seed left the high bits (which random(in:) samples)
        // near-constant, so a daily pick barely changed. The diffused seed must vary the draw.
        func draw(onDay day: Int) -> Int {
            let daily = DailySeed(now: { Date(timeIntervalSince1970: Double(day) * 86_400) })
            var rng = SeededRandomNumberGenerator(seed: daily.seed)
            return Int.random(in: 0..<1000, using: &rng)
        }
        let days = 20_000...20_009
        let seeds = Set(
            days.map { day in
                DailySeed(now: { Date(timeIntervalSince1970: Double(day) * 86_400) }).seed
            })
        let draws = Set(days.map(draw))
        #expect(seeds.count == days.count)  // every day a distinct seed
        #expect(draws.count >= 8)  // and the bounded draw genuinely varies day to day
    }

    @Test func timezone_shifts_the_day_boundary() {
        // Two instants an hour apart straddling UTC midnight between day 0 and day 1.
        let justAfterUTCMidnight = Date(timeIntervalSince1970: 86_400 + 1800)  // day 1, 00:30 UTC
        let justBeforeUTCMidnight = Date(timeIntervalSince1970: 86_400 - 1800)  // day 0, 23:30 UTC

        let utc = DailySeed()
        // In UTC they fall on different calendar days.
        #expect(utc.dayIndex(for: justAfterUTCMidnight) != utc.dayIndex(for: justBeforeUTCMidnight))

        // Shift the zone west by an hour and both instants land on the same local day, because the
        // local midnight boundary has moved.
        let minusOne = DailySeed(timeZone: TimeZone(secondsFromGMT: -3600)!)
        #expect(
            minusOne.dayIndex(for: justAfterUTCMidnight)
                == minusOne.dayIndex(for: justBeforeUTCMidnight))
    }

    @Test func new_day_available_when_last_run_was_earlier_day() {
        let now = Date(timeIntervalSince1970: 100_000)  // day 1
        let daily = DailySeed(now: { now })
        #expect(daily.isNewDayAvailable(since: Date(timeIntervalSince1970: 0)))  // day 0
    }

    @Test func new_day_not_available_within_same_day() {
        let now = Date(timeIntervalSince1970: 100_000)
        let daily = DailySeed(now: { now })
        #expect(!daily.isNewDayAvailable(since: now))
    }

    @Test func clock_moved_backward_reports_no_new_day() {
        let now = Date(timeIntervalSince1970: 100_000)  // day 1
        let daily = DailySeed(now: { now })
        let future = Date(timeIntervalSince1970: 300_000)  // day 3
        #expect(!daily.isNewDayAvailable(since: future))
    }
}
