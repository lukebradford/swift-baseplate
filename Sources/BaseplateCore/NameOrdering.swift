import Foundation

/// Finder-style, numeric-aware ordering of user-visible names, so `"file2"` sorts before
/// `"file10"` instead of after it.
///
/// A plain string `<` compares character by character, so `"file10"` lands before `"file2"`
/// (because `'1' < '2'`) — the "why is my file list scrambled?" bug. ``NameOrdering`` uses
/// `localizedStandardCompare`, the exact comparison Finder uses: case-insensitive,
/// diacritic-insensitive, and numeric-aware. A plain `compare` tie-break is applied afterward so
/// the ordering is a *total* order — two names that differ only in case or accent (`"pad"` vs
/// `"Pad"`) get a stable, repeatable position instead of swapping between runs.
///
/// - Note: `localizedStandardCompare` intentionally honors the user's current locale (that is what
///   makes it match Finder). ASCII/numeric cases like `"file2" < "file10"` are stable across all
///   locales; locale only affects the ordering of accented or script-specific letters.
///
/// ```swift
/// let files = ["file10", "file2", "file1"]
/// print(NameOrdering.sortedByName(files))   // ["file1", "file2", "file10"]
/// print(NameOrdering.compare("Track 2", "Track 10") == .orderedAscending)   // true
/// ```
public enum NameOrdering {

    /// Compares two names with Finder semantics, breaking ties for a total order.
    ///
    /// ```swift
    /// print(NameOrdering.compare("img9", "img10") == .orderedAscending)   // true
    /// print(NameOrdering.compare("a", "a") == .orderedSame)               // true
    /// ```
    ///
    /// - Parameters:
    ///   - a: The first name.
    ///   - b: The second name.
    /// - Returns: `.orderedAscending` if `a` sorts before `b`, `.orderedDescending` if after, and
    ///   `.orderedSame` only when the two strings are genuinely identical.
    public static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let result = a.localizedStandardCompare(b)
        if result != .orderedSame {
            return result
        }
        // localizedStandardCompare treats case/accent-only differences as equal; a plain compare
        // makes the order total and therefore stable across runs.
        return a.compare(b)
    }

    /// A `sorted(by:)`-compatible predicate: `true` when `a` should precede `b`.
    ///
    /// ```swift
    /// let sorted = ["b10", "b2"].sorted(by: NameOrdering.areInIncreasingOrder)
    /// print(sorted)   // ["b2", "b10"]
    /// ```
    ///
    /// - Parameters:
    ///   - a: The candidate earlier name.
    ///   - b: The candidate later name.
    /// - Returns: `true` iff ``compare(_:_:)`` orders `a` strictly before `b`.
    public static func areInIncreasingOrder(_ a: String, _ b: String) -> Bool {
        compare(a, b) == .orderedAscending
    }

    /// Returns the names sorted with Finder semantics.
    ///
    /// ```swift
    /// print(NameOrdering.sortedByName(["z", "a10", "a2"]))   // ["a2", "a10", "z"]
    /// ```
    ///
    /// - Parameter names: Any sequence of names.
    /// - Returns: A new array ordered by ``compare(_:_:)``.
    public static func sortedByName(_ names: some Sequence<String>) -> [String] {
        names.sorted(by: areInIncreasingOrder)
    }

    /// Returns `elements` sorted by a name derived from each one.
    ///
    /// Use this when the things you are ordering are not bare strings but records with a display
    /// name (files, tracks, saved documents).
    ///
    /// ```swift
    /// struct Song { let title: String }
    /// let songs = [Song(title: "Take 10"), Song(title: "Take 2")]
    /// let ordered = NameOrdering.sortedByName(songs, by: \.title)
    /// print(ordered.map(\.title))   // ["Take 2", "Take 10"]
    /// ```
    ///
    /// - Parameters:
    ///   - elements: The values to sort.
    ///   - name: Extracts the display name to order each element by.
    /// - Returns: A new array of `elements` ordered by their extracted names.
    public static func sortedByName<Element>(
        _ elements: some Sequence<Element>,
        by name: (Element) -> String
    ) -> [Element] {
        elements.sorted { areInIncreasingOrder(name($0), name($1)) }
    }
}
