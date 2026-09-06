#if canImport(UIKit)
import SwiftUI
import UIKit

extension View {
    /// Renders this view to a `UIImage` off-screen, at the given pixel scale.
    ///
    /// Uses `ImageRenderer`, so the view is laid out and drawn without ever appearing on screen —
    /// ideal for producing a shareable score card, receipt, or badge to hand to
    /// ``ShareSheet``. Because `ImageRenderer` touches the view graph, the call is `@MainActor`.
    /// Returns `nil` if rendering fails (for example, a zero-sized view).
    ///
    /// ```swift
    /// import SwiftUI
    ///
    /// @MainActor
    /// func makeBadge() -> UIImage? {
    ///     let card = Text("Level 7")
    ///         .padding()
    ///         .background(Color.yellow)
    ///     return card.exportedAsImage(scale: 3)
    /// }
    /// ```
    ///
    /// - Parameter scale: The pixel scale (points-to-pixels). Use `3` for share images destined
    ///   for Retina displays, or the current display scale to match on-screen rendering. Defaults
    ///   to `3`.
    /// - Returns: The rendered image, or `nil` if rendering produced no image.
    @MainActor
    public func exportedAsImage(scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = scale
        return renderer.uiImage
    }
}
#endif
