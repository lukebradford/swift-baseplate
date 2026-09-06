import Foundation

/// Locale-safe humanization of dates, sizes, durations, and numbers into short display strings.
///
/// Every function is a pure transform of its inputs with the locale (and, where relevant, the
/// reference "now") injected, so the same inputs always produce the same string and a test can
/// assert the exact text. Nothing here reads the ambient locale or the wall clock implicitly —
/// that is what makes these deterministic. Under the hood each function uses the Foundation
/// formatter that produces correct, localized, pluralized output; Baseplate's job is only to give
/// them a small, uniform, injectable surface.
///
/// ```swift
/// let en = Locale(identifier: "en_US")
/// let now = Date(timeIntervalSince1970: 10_000)
/// print(Humanize.relativeDate(now.addingTimeInterval(-10_800), relativeTo: now, locale: en))
/// // "3 hours ago"
/// print(Humanize.ordinal(2, locale: en))                 // "2nd"
/// print(Humanize.byteCount(1_500_000, locale: en))       // "1.5 MB"
/// ```
public enum Humanize {

    /// A friendly relative description of `date` as seen from `reference`, e.g. `"3 hours ago"`.
    ///
    /// ```swift
    /// let en = Locale(identifier: "en_US")
    /// let now = Date(timeIntervalSince1970: 0)
    /// print(Humanize.relativeDate(now.addingTimeInterval(-3600), relativeTo: now, locale: en))
    /// // "1 hour ago"
    /// ```
    ///
    /// - Parameters:
    ///   - date: The date being described.
    ///   - reference: The "now" the description is relative to. Inject a fixed value for tests.
    ///   - locale: The locale for wording and pluralization. Defaults to `.autoupdatingCurrent`.
    /// - Returns: A localized phrase such as `"3 hours ago"` or `"in 2 days"`.
    public static func relativeDate(
        _ date: Date,
        relativeTo reference: Date,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: reference)
    }

    /// A localized human-readable file size, e.g. `"1.5 MB"`.
    ///
    /// ```swift
    /// let en = Locale(identifier: "en_US")
    /// print(Humanize.byteCount(512, locale: en))   // "512 bytes"
    /// ```
    ///
    /// - Parameters:
    ///   - bytes: The size in bytes.
    ///   - style: The unit convention. Defaults to `.file` (decimal, 1 KB = 1000 bytes), matching
    ///     how the Finder reports file sizes.
    ///   - locale: The locale for the number and unit. Defaults to `.autoupdatingCurrent`.
    /// - Returns: A localized size string such as `"1.5 MB"` or `"512 bytes"`.
    public static func byteCount(
        _ bytes: Int64,
        style: ByteCountFormatStyle.Style = .file,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        bytes.formatted(ByteCountFormatStyle(style: style, locale: locale))
    }

    /// A localized human-readable duration, e.g. `"1 hour, 1 minute"`.
    ///
    /// ```swift
    /// let en = Locale(identifier: "en_US")
    /// print(Humanize.duration(3661, locale: en))
    /// // "1 hour, 1 minute, 1 second"
    /// ```
    ///
    /// - Parameters:
    ///   - seconds: The length of the interval in seconds. Negative values are treated as their
    ///     magnitude.
    ///   - allowed: Which units may appear, largest to smallest. Defaults to hours/minutes/seconds.
    ///   - width: How units are spelled (`.wide` → `"hour"`, `.abbreviated` → `"hr"`,
    ///     `.narrow` → `"h"`). Defaults to `.wide`.
    ///   - locale: The locale for wording and pluralization. Defaults to `.autoupdatingCurrent`.
    /// - Returns: A localized duration string such as `"1 hour, 1 minute, 1 second"`.
    public static func duration(
        _ seconds: TimeInterval,
        allowed: Set<Duration.UnitsFormatStyle.Unit> = [.hours, .minutes, .seconds],
        width: Duration.UnitsFormatStyle.UnitWidth = .wide,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let duration = Duration.seconds(abs(seconds))
        return duration.formatted(
            .units(allowed: allowed, width: width).locale(locale)
        )
    }

    /// A localized ordinal form of an integer, e.g. `1` → `"1st"`.
    ///
    /// ```swift
    /// let en = Locale(identifier: "en_US")
    /// print(Humanize.ordinal(3, locale: en))   // "3rd"
    /// ```
    ///
    /// - Parameters:
    ///   - value: The integer to render as an ordinal.
    ///   - locale: The locale for the ordinal form. Defaults to `.autoupdatingCurrent`.
    /// - Returns: A localized ordinal such as `"1st"`, `"2nd"`, `"3rd"`, or `value` itself as a
    ///   string if the platform cannot form an ordinal for it.
    public static func ordinal(_ value: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        formatter.locale = locale
        return formatter.string(from: value as NSNumber) ?? String(value)
    }
}
