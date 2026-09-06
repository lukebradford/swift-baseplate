import Foundation
import Testing

@testable import BaseplateCore

@Suite struct HumanizeTests {

    private let en = Locale(identifier: "en_US")

    @Test func relative_date_hours_ago() {
        let now = Date(timeIntervalSince1970: 100_000)
        let earlier = now.addingTimeInterval(-3 * 3600)
        #expect(Humanize.relativeDate(earlier, relativeTo: now, locale: en) == "3 hours ago")
    }

    @Test func relative_date_singular_hour() {
        let now = Date(timeIntervalSince1970: 100_000)
        let earlier = now.addingTimeInterval(-3600)
        #expect(Humanize.relativeDate(earlier, relativeTo: now, locale: en) == "1 hour ago")
    }

    @Test func relative_date_in_the_future() {
        let now = Date(timeIntervalSince1970: 100_000)
        let later = now.addingTimeInterval(2 * 86_400)
        #expect(Humanize.relativeDate(later, relativeTo: now, locale: en) == "in 2 days")
    }

    @Test func byte_count_small_is_in_bytes() {
        #expect(Humanize.byteCount(512, locale: en) == "512 bytes")
    }

    @Test func byte_count_megabytes() {
        #expect(Humanize.byteCount(1_500_000, locale: en) == "1.5 MB")
    }

    @Test func duration_hours_minutes_seconds() {
        #expect(Humanize.duration(3661, locale: en) == "1 hour, 1 minute, 1 second")
    }

    @Test func duration_ignores_sign() {
        #expect(Humanize.duration(-3661, locale: en) == "1 hour, 1 minute, 1 second")
    }

    @Test func ordinal_forms() {
        #expect(Humanize.ordinal(1, locale: en) == "1st")
        #expect(Humanize.ordinal(2, locale: en) == "2nd")
        #expect(Humanize.ordinal(3, locale: en) == "3rd")
        #expect(Humanize.ordinal(4, locale: en) == "4th")
        #expect(Humanize.ordinal(11, locale: en) == "11th")
        #expect(Humanize.ordinal(21, locale: en) == "21st")
    }
}
