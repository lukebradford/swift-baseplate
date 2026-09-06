import SwiftUI

/// sRGB(A) color components in the `0...1` range — a `Codable`, `Sendable` stand-in for `Color`.
///
/// `SwiftUI.Color` is not `Codable`, so a user-chosen color cannot be persisted directly. Store
/// these components instead: they round-trip losslessly through `Codable`, parse from and format
/// to hex, and convert to and from `Color`. Values are conventionally in `0...1`; components
/// outside that range are preserved as given but are clamped when formatting to a hex string.
///
/// ```swift
/// import Foundation
///
/// let orange = ColorComponents(red: 1, green: 0.5, blue: 0, alpha: 1)
/// let data = try JSONEncoder().encode(orange)
/// let restored = try JSONDecoder().decode(ColorComponents.self, from: data)
/// print(restored == orange)   // true
/// ```
public struct ColorComponents: Codable, Hashable, Sendable {
    /// The red component, conventionally in `0...1`.
    public var red: Double
    /// The green component, conventionally in `0...1`.
    public var green: Double
    /// The blue component, conventionally in `0...1`.
    public var blue: Double
    /// The alpha (opacity) component, conventionally in `0...1`.
    public var alpha: Double

    /// Creates components from explicit channel values.
    ///
    /// ```swift
    /// let gray = ColorComponents(red: 0.5, green: 0.5, blue: 0.5)
    /// print(gray.alpha)   // 1.0
    /// ```
    ///
    /// - Parameters:
    ///   - red: The red component, conventionally in `0...1`.
    ///   - green: The green component, conventionally in `0...1`.
    ///   - blue: The blue component, conventionally in `0...1`.
    ///   - alpha: The alpha component, conventionally in `0...1`. Defaults to `1` (opaque).
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Parses components from a hex color string.
    ///
    /// Accepts an optional leading `#` and one of three digit counts: `RGB` (each nibble is
    /// doubled, so `F` becomes `FF`), `RRGGBB`, or `RRGGBBAA`. Parsing is case-insensitive and
    /// tolerates surrounding whitespace. Any other length, or a non-hex character, returns `nil`.
    /// A string without an alpha pair is fully opaque (`alpha == 1`).
    ///
    /// ```swift
    /// let teal = ColorComponents(hex: "#0FC")      // expands to 00FFCC
    /// print(teal?.blue ?? -1)                       // 0.8
    /// print(ColorComponents(hex: "not a color"))    // nil
    /// ```
    ///
    /// - Parameter hex: A `#RGB`, `#RRGGBB`, or `#RRGGBBAA` string (the `#` is optional).
    public init?(hex: String) {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("#") { string.removeFirst() }

        let expanded: String
        switch string.count {
        case 3:
            // #RGB → #RRGGBB by doubling each nibble.
            expanded = string.map { "\($0)\($0)" }.joined()
        case 6, 8:
            expanded = string
        default:
            return nil
        }

        guard let value = UInt32(expanded, radix: 16) else { return nil }

        if expanded.count == 8 {
            self.red = Double((value >> 24) & 0xFF) / 255
            self.green = Double((value >> 16) & 0xFF) / 255
            self.blue = Double((value >> 8) & 0xFF) / 255
            self.alpha = Double(value & 0xFF) / 255
        } else {
            self.red = Double((value >> 16) & 0xFF) / 255
            self.green = Double((value >> 8) & 0xFF) / 255
            self.blue = Double(value & 0xFF) / 255
            self.alpha = 1
        }
    }

    /// The components formatted as an uppercase `#RRGGBB` (or `#RRGGBBAA`) string.
    ///
    /// Each channel is clamped to `0...1` and rounded to the nearest 8-bit value. The alpha pair is
    /// included only when `alpha` is less than `1`, so an opaque color produces the shorter form —
    /// which parses back to an identical value via ``init(hex:)``.
    ///
    /// ```swift
    /// let c = ColorComponents(red: 1, green: 0.5, blue: 0)
    /// print(c.hexString)   // "#FF8000"
    /// ```
    public var hexString: String {
        func channel(_ value: Double) -> Int {
            Int((min(max(value, 0), 1) * 255).rounded())
        }
        let r = channel(red)
        let g = channel(green)
        let b = channel(blue)
        if alpha < 1 {
            let a = channel(alpha)
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// The equivalent SwiftUI `Color` in the sRGB color space.
    ///
    /// ```swift
    /// import SwiftUI
    ///
    /// let swatch = ColorComponents(red: 0.2, green: 0.4, blue: 0.8).color
    /// _ = swatch   // use in a view
    /// ```
    public var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    /// Extracts components from a resolved `Color`.
    ///
    /// Resolving flattens the color to concrete sRGB channel values in the given environment (needed
    /// because a `Color` may be dynamic or asset-backed). The default environment is sufficient for
    /// the plain, non-adaptive colors a color picker produces.
    ///
    /// ```swift
    /// import SwiftUI
    ///
    /// let components = ColorComponents(resolving: .red)
    /// print(components.red > 0.9)   // true
    /// ```
    ///
    /// - Parameters:
    ///   - color: The color to flatten to sRGB components.
    ///   - environment: The environment the color resolves against. Defaults to a fresh
    ///     `EnvironmentValues`.
    public init(resolving color: Color, in environment: EnvironmentValues = EnvironmentValues()) {
        let resolved = color.resolve(in: environment)
        self.red = Double(resolved.red)
        self.green = Double(resolved.green)
        self.blue = Double(resolved.blue)
        self.alpha = Double(resolved.opacity)
    }
}
