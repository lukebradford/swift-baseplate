import SwiftUI
import Testing

@testable import BaseplateUI

@MainActor
@Suite struct BindingIsPresentTests {

    /// A mutable reference cell so a `Binding` has real backing storage in a test.
    private final class Box<Value> {
        var value: Value
        init(_ value: Value) { self.value = value }
    }

    @Test func is_true_when_optional_has_a_value() {
        let box = Box<Int?>(42)
        let source = Binding<Int?>(get: { box.value }, set: { box.value = $0 })
        #expect(source.isPresent().wrappedValue == true)
    }

    @Test func is_false_when_optional_is_nil() {
        let box = Box<Int?>(nil)
        let source = Binding<Int?>(get: { box.value }, set: { box.value = $0 })
        #expect(source.isPresent().wrappedValue == false)
    }

    @Test func setting_false_clears_the_optional() {
        let box = Box<Int?>(7)
        let source = Binding<Int?>(get: { box.value }, set: { box.value = $0 })
        source.isPresent().wrappedValue = false
        #expect(box.value == nil)
    }

    @Test func setting_true_does_not_fabricate_a_value() {
        let box = Box<Int?>(nil)
        let source = Binding<Int?>(get: { box.value }, set: { box.value = $0 })
        source.isPresent().wrappedValue = true
        #expect(box.value == nil)  // presentation happens by assigning a real value, not this flag
    }

    @Test func reflects_a_string_error_message_optional() {
        let box = Box<String?>(nil)
        let source = Binding<String?>(get: { box.value }, set: { box.value = $0 })
        let present = source.isPresent()
        #expect(present.wrappedValue == false)
        box.value = "boom"
        #expect(present.wrappedValue == true)
    }
}
