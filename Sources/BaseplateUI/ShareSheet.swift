#if canImport(UIKit)
import SwiftUI
import UIKit

/// A SwiftUI wrapper over `UIActivityViewController` (the system share sheet).
///
/// Present it from `.sheet(isPresented:)` or `.sheet(item:)` to share text, URLs, or images. The
/// optional ``onComplete`` callback reports how the sheet closed — which activity the user picked
/// and whether the share actually completed — so a caller can log analytics or update UI. It is
/// `nil` by default, so call sites that don't care are unaffected.
///
/// ```swift
/// import SwiftUI
///
/// struct Demo: View {
///     @State private var showing = false
///     var body: some View {
///         Button("Share") { showing = true }
///             .sheet(isPresented: $showing) {
///                 ShareSheet(items: ["Hello from Baseplate"]) { activity, completed in
///                     print("picked \(activity), completed: \(completed)")
///                 }
///             }
///     }
/// }
/// ```
public struct ShareSheet: UIViewControllerRepresentable {
    /// The items to share (strings, URLs, `UIImage`s, or any activity item).
    public let items: [Any]

    /// Called when the sheet closes. `activity` is the chosen activity type's raw value (e.g.
    /// `"com.apple.UIKit.activity.Message"`), or `"dismissed"` if the user backed out without
    /// sharing; `completed` is whether the share finished.
    public var onComplete: (@MainActor (_ activity: String, _ completed: Bool) -> Void)?

    /// Creates a share sheet for the given activity items.
    ///
    /// ```swift
    /// let sheet = ShareSheet(items: ["Hello"])
    /// _ = sheet
    /// ```
    ///
    /// - Parameters:
    ///   - items: The activity items to share.
    ///   - onComplete: An optional completion callback reporting the chosen activity and whether
    ///     the share completed. Defaults to `nil`.
    public init(
        items: [Any],
        onComplete: (@MainActor (_ activity: String, _ completed: Bool) -> Void)? = nil
    ) {
        self.items = items
        self.onComplete = onComplete
    }

    /// Builds the underlying `UIActivityViewController`. Called by SwiftUI; not for direct use.
    ///
    /// ```swift
    /// // SwiftUI calls this for you when the sheet is presented.
    /// ```
    ///
    /// - Parameter context: The representable context provided by SwiftUI.
    /// - Returns: A configured activity view controller.
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            onComplete?(activityType?.rawValue ?? "dismissed", completed)
        }
        return controller
    }

    /// Required by `UIViewControllerRepresentable`; the share sheet needs no updates.
    ///
    /// ```swift
    /// // No-op: the activity controller is configured once at creation.
    /// ```
    ///
    /// - Parameters:
    ///   - uiViewController: The existing activity view controller.
    ///   - context: The representable context provided by SwiftUI.
    public func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
#endif
