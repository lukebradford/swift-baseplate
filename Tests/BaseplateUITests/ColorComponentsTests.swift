import Foundation
import SwiftUI
import Testing

@testable import BaseplateUI

@Suite struct ColorComponentsTests {

    // MARK: Hex parsing — happy paths

    @Test func parses_six_digit_hex() {
        let c = ColorComponents(hex: "#FF8000")
        #expect(c != nil)
        #expect(abs(c!.red - 1.0) < 1e-9)
        #expect(abs(c!.green - 128.0 / 255.0) < 1e-9)
        #expect(c!.blue == 0)
        #expect(c!.alpha == 1)
    }

    @Test func parses_without_leading_hash() {
        #expect(ColorComponents(hex: "FF8000") == ColorComponents(hex: "#FF8000"))
    }

    @Test func parses_three_digit_shorthand_by_doubling_nibbles() {
        // #0FC expands to #00FFCC.
        let short = ColorComponents(hex: "#0FC")
        let long = ColorComponents(hex: "#00FFCC")
        #expect(short == long)
        #expect(abs(short!.blue - 204.0 / 255.0) < 1e-9)
    }

    @Test func parses_eight_digit_hex_with_alpha() {
        let c = ColorComponents(hex: "#FF880080")
        #expect(c != nil)
        #expect(abs(c!.alpha - 128.0 / 255.0) < 1e-9)
    }

    @Test func parsing_is_case_insensitive_and_trims_whitespace() {
        #expect(ColorComponents(hex: "  #ff8000  ") == ColorComponents(hex: "#FF8000"))
    }

    // MARK: Hex parsing — edges / corrupt input

    @Test func rejects_wrong_length() {
        #expect(ColorComponents(hex: "#FF80") == nil)  // 4 digits
        #expect(ColorComponents(hex: "#FF800") == nil)  // 5 digits
        #expect(ColorComponents(hex: "#FF80000000") == nil)  // 10 digits
    }

    @Test func rejects_non_hex_characters() {
        #expect(ColorComponents(hex: "not a color") == nil)
        #expect(ColorComponents(hex: "#GGGGGG") == nil)
    }

    @Test func rejects_empty_string() {
        #expect(ColorComponents(hex: "") == nil)
        #expect(ColorComponents(hex: "#") == nil)
    }

    // MARK: hexString round-trips

    @Test func hex_string_round_trips_opaque() {
        let original = "#FF8000"
        let parsed = ColorComponents(hex: original)!
        #expect(parsed.hexString == original)
    }

    @Test func hex_string_includes_alpha_only_when_translucent() {
        let opaque = ColorComponents(red: 1, green: 0.5, blue: 0, alpha: 1)
        #expect(opaque.hexString == "#FF8000")

        let translucent = ColorComponents(hex: "#FF880080")!
        #expect(translucent.hexString == "#FF880080")
    }

    @Test func hex_string_clamps_out_of_range_components() {
        let overshoot = ColorComponents(red: 2, green: -1, blue: 0.5, alpha: 1)
        #expect(overshoot.hexString == "#FF0080")
    }

    // MARK: Codable round-trip (the persistence contract)

    @Test func codable_round_trips_exactly() throws {
        let original = ColorComponents(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4)
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(ColorComponents.self, from: data)
        #expect(restored == original)
    }

    @Test func decodes_from_stable_json_shape() throws {
        let json = Data(#"{"red":1,"green":0.5,"blue":0,"alpha":1}"#.utf8)
        let decoded = try JSONDecoder().decode(ColorComponents.self, from: json)
        #expect(decoded == ColorComponents(red: 1, green: 0.5, blue: 0, alpha: 1))
    }

    // MARK: Color <-> components bridge

    @MainActor
    @Test func resolving_a_color_recovers_its_components() {
        let components = ColorComponents(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)
        let recovered = ColorComponents(resolving: components.color)
        #expect(abs(recovered.red - 0.2) < 0.02)
        #expect(abs(recovered.green - 0.4) < 0.02)
        #expect(abs(recovered.blue - 0.8) < 0.02)
        #expect(abs(recovered.alpha - 1.0) < 0.02)
    }

    @MainActor
    @Test func color_from_hex_resolves_to_expected_channels() {
        let red = Color(hex: "#FF0000")
        #expect(red != nil)
        let recovered = ColorComponents(resolving: red!)
        #expect(recovered.red > 0.9)
        #expect(recovered.green < 0.1)
        #expect(recovered.blue < 0.1)
    }

    @Test func color_from_invalid_hex_is_nil() {
        #expect(Color(hex: "bogus") == nil)
    }
}
