import Testing

@testable import BaseplateCore

@Suite struct CollectionSafeSubscriptTests {

    @Test func returns_element_at_valid_index() {
        let items = ["a", "b", "c"]
        #expect(items[safe: 0] == "a")
        #expect(items[safe: 2] == "c")
    }

    @Test func returns_nil_past_the_end() {
        let items = ["a", "b"]
        #expect(items[safe: 2] == nil)
        #expect(items[safe: 99] == nil)
    }

    @Test func returns_nil_for_negative_index() {
        let items = [1, 2, 3]
        #expect(items[safe: -1] == nil)
    }

    @Test func empty_collection_is_always_nil() {
        let empty: [Int] = []
        #expect(empty[safe: 0] == nil)
    }

    @Test func works_on_array_slice_with_offset_indices() {
        let slice = [10, 20, 30, 40][2...]  // indices 2...3
        #expect(slice[safe: 2] == 30)
        #expect(slice[safe: 0] == nil)  // 0 is out of the slice's index range
    }
}
