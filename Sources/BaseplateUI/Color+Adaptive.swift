import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

extension Color {
    /// A color that resolves to `light` in light appearance and `dark` in dark appearance.
    ///
    /// Unlike `Color`'s asset-catalog dynamic colors, this builds one in code from two static
    /// colors, so a design system can express its light/dark pairs inline. On platforms without
    /// UIKit (portable/macOS builds) there is no trait environment to resolve against, so `light`
    /// is returned unchanged.
    ///
    /// ```swift
    /// import SwiftUI
    ///
    /// let separator = Color.adaptive(
    ///     light: Color(hex: "#E0E0E0")!,
    ///     dark: Color(hex: "#2C2C2E")!
    /// )
    /// _ = separator
    /// ```
    ///
    /// - Parameters:
    ///   - light: The color used in light appearance (and the fallback where trait resolution is
    ///     unavailable).
    ///   - dark: The color used in dark appearance.
    /// - Returns: A color that adapts to the current color scheme.
    public static func adaptive(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        return Color(UIColor.adaptive(light: UIColor(light), dark: UIColor(dark)))
        #else
        return light
        #endif
    }
}

#if canImport(UIKit)
extension UIColor {
    /// A `UIColor` that resolves to `light` in light appearance and `dark` in dark appearance.
    ///
    /// The UIKit counterpart of ``SwiftUICore/Color/adaptive(light:dark:)``, for call sites that
    /// need a `UIColor` (tint colors, attributed strings, `CALayer` fills). Resolution happens
    /// per trait collection, so a single value renders correctly in both appearances.
    ///
    /// ```swift
    /// import UIKit
    ///
    /// let fill = UIColor.adaptive(light: .white, dark: .black)
    /// let inDark = fill.resolvedColor(
    ///     with: UITraitCollection(userInterfaceStyle: .dark)
    /// )
    /// _ = inDark
    /// ```
    ///
    /// - Parameters:
    ///   - light: The color used in light appearance (and for any unspecified style).
    ///   - dark: The color used in dark appearance.
    /// - Returns: A dynamic `UIColor` that adapts to the interface style.
    public static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }
    }
}
#endif
