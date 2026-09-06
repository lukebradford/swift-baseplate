import SwiftUI

/// The modifier backing ``SwiftUICore/View/scaledFont(size:weight:design:relativeTo:)``.
///
/// It holds a `@ScaledMetric` seeded with the base point size and anchored to a chosen text
/// style, then applies `Font.system(size:weight:design:)` using the scaled value. Kept private
/// because callers use the `View` method, never the modifier directly.
private struct ScaledFontModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(
        size: CGFloat, weight: Font.Weight, design: Font.Design,
        relativeTo textStyle: Font.TextStyle
    ) {
        self._size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {
    /// Applies a fixed-point-size system font that scales with the user's Dynamic Type setting.
    ///
    /// `Font.system(size:weight:design:)` is a *fixed* size — it ignores Dynamic Type entirely, so
    /// a UI built on tuned point sizes gains no accessibility scaling. This modifier keeps the base
    /// `size` but drives it through `@ScaledMetric`, anchored to `textStyle`, so it grows and
    /// shrinks along that style's curve. At the default Dynamic Type size the rendered size equals
    /// `size` exactly, leaving the existing look unchanged for most users while larger accessibility
    /// sizes scale up from there. Pick the `textStyle` closest to the text's role (`.title` for
    /// headers, `.body` for content, `.caption` for small labels) so growth feels proportional.
    ///
    /// ```swift
    /// import SwiftUI
    ///
    /// struct Header: View {
    ///     var body: some View {
    ///         Text("Welcome")
    ///             .scaledFont(size: 28, weight: .bold, design: .rounded, relativeTo: .title)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - size: The base point size, rendered exactly at the default Dynamic Type size.
    ///   - weight: The font weight. Defaults to `.regular`.
    ///   - design: The font design. Defaults to `.default`.
    ///   - textStyle: The text style whose Dynamic Type scaling curve the size follows. Defaults to
    ///     `.body`.
    /// - Returns: A view rendering its content in the scaled system font.
    public func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> some View {
        modifier(
            ScaledFontModifier(size: size, weight: weight, design: design, relativeTo: textStyle)
        )
    }
}
