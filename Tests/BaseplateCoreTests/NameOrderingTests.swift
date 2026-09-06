import Foundation
import Testing

@testable import BaseplateCore

@Suite struct NameOrderingTests {

    @Test func numeric_aware_ordering() {
        let sorted = NameOrdering.sortedByName(["file10", "file2", "file1"])
        #expect(sorted == ["file1", "file2", "file10"])
    }

    @Test func track_numbers_sort_numerically_not_lexically() {
        #expect(NameOrdering.compare("Track 2", "Track 10") == .orderedAscending)
        #expect(NameOrdering.compare("Track 10", "Track 2") == .orderedDescending)
    }

    @Test func identical_strings_are_ordered_same() {
        #expect(NameOrdering.compare("abc", "abc") == .orderedSame)
    }

    @Test func case_only_difference_is_stable_not_equal() {
        // localizedStandardCompare treats these as equal; the tie-break makes the order total,
        // so it must be a strict, repeatable ordering rather than .orderedSame.
        let result = NameOrdering.compare("Pad", "pad")
        #expect(result != .orderedSame)
    }

    @Test func predicate_is_sorted_by_compatible() {
        let sorted = ["b10", "b2", "b1"].sorted(by: NameOrdering.areInIncreasingOrder)
        #expect(sorted == ["b1", "b2", "b10"])
    }

    @Test func sorts_records_by_extracted_name() {
        struct Song { let title: String }
        let songs = [Song(title: "Take 10"), Song(title: "Take 2"), Song(title: "Take 1")]
        let ordered = NameOrdering.sortedByName(songs, by: \.title)
        #expect(ordered.map(\.title) == ["Take 1", "Take 2", "Take 10"])
    }

    @Test func empty_input_returns_empty() {
        #expect(NameOrdering.sortedByName([String]()) == [])
    }
}
