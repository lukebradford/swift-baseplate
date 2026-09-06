import SwiftUI

extension View {
    /// Conditionally applies a transform to this view.
    ///
    /// A convenience for the "apply this modifier only when a flag is set" pattern, avoiding a
    /// duplicated view body in each branch.
    ///
    /// - Important: **This changes view identity.** When `condition` flips, SwiftUI sees a different
    ///   branch of an `if`/`else` (an internal `_ConditionalContent`), so it *re-creates* the view
    ///   rather than updating it in place: `@State` inside is reset, `.matchedGeometryEffect` and
    ///   `.transition` may misbehave, and animations can jump. Reach for it only when the transform
    ///   is a purely visual, stateless modifier (a color, a corner radius). When both branches are
    ///   the *same* modifier with different values, prefer applying it unconditionally with a
    ///   computed value (e.g. `.opacity(flag ? 1 : 0)`), which preserves identity.
    ///
    /// ```swift
    /// import SwiftUI
    ///
    /// struct Demo: View {
    ///     let highlighted: Bool
    ///     var body: some View {
    ///         Text("Item")
    ///             .if(highlighted) { $0.background(Color.yellow) }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - condition: When `true`, `transform` is applied; when `false`, the view is left unchanged.
    ///   - transform: A closure that receives this view and returns the transformed view.
    /// - Returns: The transformed view when `condition` is `true`, otherwise this view unchanged.
    @ViewBuilder
    public func `if`<Transformed: View>(
        _ condition: Bool,
        transform: (Self) -> Transformed
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
