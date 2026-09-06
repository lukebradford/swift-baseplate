import SwiftUI

extension Binding {
    /// Derives a `Bool` binding that is `true` while an optional binding holds a value.
    ///
    /// The common bridge between "I have an optional piece of state" and an API that wants
    /// `isPresented: Binding<Bool>` (such as `.alert(_:isPresented:)` or `.sheet(isPresented:)`).
    /// Reading is `true` exactly when the wrapped optional is non-`nil`; setting it to `false`
    /// clears the optional to `nil`. Setting it to `true` is ignored — you present by assigning a
    /// concrete value to the source binding, not by flipping this flag on.
    ///
    /// ```swift
    /// import SwiftUI
    ///
    /// struct Demo: View {
    ///     @State private var message: String?
    ///     var body: some View {
    ///         Text("Hi")
    ///             .alert("Notice", isPresented: $message.isPresent()) {
    ///                 Button("OK") {}
    ///             }
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: A `Binding<Bool>` that reflects, and can clear, the optional's presence.
    public func isPresent<Wrapped: Sendable>() -> Binding<Bool> where Value == Wrapped? {
        Binding<Bool>(
            get: { self.wrappedValue != nil },
            set: { isPresented in
                if !isPresented { self.wrappedValue = nil }
            }
        )
    }
}
