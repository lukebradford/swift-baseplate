#if canImport(UIKit)
import UIKit

/// An `Identifiable` wrapper around a `UIImage`, for driving `.sheet(item:)`.
///
/// `.sheet(item:)` requires its item to be `Identifiable`, but `UIImage` is not. Wrap a rendered
/// image in this type and store it in optional `@State`; assigning a value presents the sheet and
/// setting it back to `nil` dismisses it. Each wrapper gets a fresh identity, so presenting a new
/// image while a sheet is open re-presents it.
///
/// ```swift
/// import SwiftUI
/// import UIKit
///
/// struct Demo: View {
///     @State private var shared: ShareableImage?
///     var body: some View {
///         Button("Share") { shared = ShareableImage(image: UIImage()) }
///             .sheet(item: $shared) { item in
///                 ShareSheet(items: [item.image])
///             }
///     }
/// }
/// ```
public struct ShareableImage: Identifiable {
    /// The stable identity that distinguishes this wrapper for `.sheet(item:)`.
    public let id = UUID()
    /// The wrapped image to share.
    public let image: UIImage

    /// Wraps an image so it can drive `.sheet(item:)`.
    ///
    /// ```swift
    /// import UIKit
    ///
    /// let item = ShareableImage(image: UIImage())
    /// _ = item.id
    /// ```
    ///
    /// - Parameter image: The image to present in a share sheet.
    public init(image: UIImage) {
        self.image = image
    }
}
#endif
