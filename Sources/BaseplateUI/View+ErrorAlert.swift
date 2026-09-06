import SwiftUI

extension View {
    /// Presents a system alert whenever an optional `Error` binding becomes non-`nil`.
    ///
    /// A tidy replacement for the usual "keep an `Error?` in `@State`, derive an `isPresented`
    /// flag, and remember to clear it" boilerplate. Bind an `Error?`: whenever it holds a value the
    /// alert shows the error's `localizedDescription`; dismissing (or the source setting it to
    /// `nil`) clears it. The dismiss button resets the binding to `nil` so the same error can be
    /// raised again later.
    ///
    /// ```swift
    /// import SwiftUI
    ///
    /// struct Demo: View {
    ///     @State private var error: Error?
    ///     var body: some View {
    ///         Button("Fail") { error = URLError(.notConnectedToInternet) }
    ///             .errorAlert($error)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - error: A binding to the optional error to present; cleared to `nil` on dismissal.
    ///   - title: The alert title. Defaults to `"Something Went Wrong"`.
    ///   - dismissTitle: The dismiss button's title. Defaults to `"OK"`.
    /// - Returns: A view that presents the error alert when `error` is non-`nil`.
    public func errorAlert(
        _ error: Binding<Error?>,
        title: String = "Something Went Wrong",
        dismissTitle: String = "OK"
    ) -> some View {
        // Derive Sendable snapshots (a `Bool` and a `String?`) so the presentation bindings capture
        // only value types, keeping the closures `Sendable`-clean even though `any Error` is not
        // `Sendable`. The alert can only be dismissed by its button, whose action clears the source.
        let message = error.wrappedValue?.localizedDescription
        let isShowing = message != nil
        return alert(
            title,
            isPresented: Binding(get: { isShowing }, set: { _ in }),
            presenting: message
        ) { _ in
            Button(dismissTitle, role: .cancel) { error.wrappedValue = nil }
        } message: { presentedMessage in
            Text(presentedMessage)
        }
    }
}
