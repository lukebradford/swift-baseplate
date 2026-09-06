import SwiftUI

extension Color {
    /// Creates a color from a hex string, or returns `nil` if the string is not valid hex.
    ///
    /// A convenience over ``ColorComponents/init(hex:)`` for the common case of a literal design
    /// color. Accepts an optional leading `#` and `RGB`, `RRGGBB`, or `RRGGBBAA` digit counts,
    /// case-insensitively. The color is interpreted in the sRGB color space.
    ///
    /// ```swift
    /// import SwiftUI
    ///
    /// let brand = Color(hex: "#FF8800")
    /// let translucent = Color(hex: "#FF880080")   // 50% alpha
    /// let invalid = Color(hex: "nope")            // nil
    /// _ = (brand, translucent, invalid)
    /// ```
    ///
    /// - Parameter hex: A `#RGB`, `#RRGGBB`, or `#RRGGBBAA` string (the `#` is optional).
    public init?(hex: String) {
        guard let components = ColorComponents(hex: hex) else { return nil }
        self = components.color
    }
}
