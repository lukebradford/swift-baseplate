import Foundation
import Testing

@testable import BaseplateStoreKit

@Suite struct GrandfatherTests {

    // MARK: isGrandfathered

    @Test func older_original_version_is_grandfathered() {
        #expect(Grandfather.isGrandfathered(originalAppVersion: "1.3", boughtBefore: "1.4"))
    }

    @Test func version_equal_to_cutoff_is_not_grandfathered() {
        #expect(!Grandfather.isGrandfathered(originalAppVersion: "1.4", boughtBefore: "1.4"))
    }

    @Test func newer_original_version_is_not_grandfathered() {
        #expect(!Grandfather.isGrandfathered(originalAppVersion: "2.0", boughtBefore: "1.4"))
    }

    @Test func numeric_components_sort_numerically_not_lexically() {
        // "1.10" is NEWER than "1.9" — a plain string compare would get this backwards.
        #expect(!Grandfather.isGrandfathered(originalAppVersion: "1.10", boughtBefore: "1.9"))
        #expect(Grandfather.isGrandfathered(originalAppVersion: "1.9", boughtBefore: "1.10"))
    }

    @Test func empty_original_version_is_treated_as_oldest() {
        #expect(Grandfather.isGrandfathered(originalAppVersion: "", boughtBefore: "1.0"))
    }

    // MARK: compare (helper)

    @Test func compare_orders_by_first_differing_component() {
        #expect(Grandfather.compare("1.2.3", "1.3.0") == .orderedAscending)
        #expect(Grandfather.compare("2.0.0", "1.9.9") == .orderedDescending)
    }

    @Test func compare_treats_missing_trailing_components_as_zero() {
        #expect(Grandfather.compare("2", "2.0.0") == .orderedSame)
        #expect(Grandfather.compare("2.0", "2") == .orderedSame)
    }

    @Test func compare_treats_malformed_segments_as_zero() {
        // "1.x" → [1, 0]; "1.0" → [1, 0] ⇒ equal, rather than crashing.
        #expect(Grandfather.compare("1.x", "1.0") == .orderedSame)
        #expect(Grandfather.compare("", "0.0.0") == .orderedSame)
    }

    @Test func compare_handles_many_components() {
        #expect(Grandfather.compare("8.11.2", "10.0.0") == .orderedAscending)
    }
}
