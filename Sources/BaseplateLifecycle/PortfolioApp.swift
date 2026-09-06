import Foundation

/// One app in a developer's portfolio, as rendered by a cross-promotion shelf.
///
/// A generic, presentation-agnostic value: a name, a one-line tagline, the numeric App Store id,
/// an icon (either an SF Symbol name or a remote URL), and an optional campaign token used to
/// attribute installs driven by this row. The library ships **no concrete portfolio** — a real list
/// of apps belongs in a consuming app or `Examples/`, never here.
///
/// ```swift
/// let app = PortfolioApp(
///     name: "Symmetry Lab",
///     tagline: "Draw mandalas with one finger",
///     appStoreID: "327084738",
///     icon: .systemName("circle.hexagongrid.fill"),
///     campaignToken: "cross_promo")
/// print(app.id)   // "327084738"
/// ```
public struct PortfolioApp: Identifiable, Sendable, Hashable {

    /// How a row draws its icon.
    public enum Icon: Sendable, Hashable {
        /// An SF Symbol name, e.g. `"circle.hexagongrid.fill"`.
        case systemName(String)
        /// A remote image URL.
        case url(URL)
    }

    /// The app's display name.
    public var name: String
    /// A short one-line description shown under the name.
    public var tagline: String
    /// The numeric App Store id (the digits from `.../id327084738`).
    public var appStoreID: String
    /// The icon to display.
    public var icon: Icon
    /// An optional App Store campaign token (`ct`) for attributing installs from this row.
    public var campaignToken: String?

    /// The stable identity, equal to ``appStoreID`` (satisfies `Identifiable`).
    public var id: String { appStoreID }

    /// Creates a portfolio app entry.
    ///
    /// ```swift
    /// let app = PortfolioApp(
    ///     name: "Megalith", tagline: "Turn a phrase into a graphic",
    ///     appStoreID: "6470254197", icon: .systemName("textformat"))
    /// ```
    ///
    /// - Parameters:
    ///   - name: The display name.
    ///   - tagline: A short one-line description.
    ///   - appStoreID: The numeric App Store id as a string.
    ///   - icon: The icon (an SF Symbol name or a URL).
    ///   - campaignToken: An optional campaign token for attribution. Defaults to `nil`.
    public init(
        name: String,
        tagline: String,
        appStoreID: String,
        icon: Icon,
        campaignToken: String? = nil
    ) {
        self.name = name
        self.tagline = tagline
        self.appStoreID = appStoreID
        self.icon = icon
        self.campaignToken = campaignToken
    }
}

extension Sequence where Element == PortfolioApp {
    /// Returns the apps in this sequence with the given App Store id removed.
    ///
    /// Use it to drop the current app from a shared portfolio list, so a cross-promotion shelf never
    /// advertises the app the user is already in.
    ///
    /// ```swift
    /// let portfolio = [
    ///     PortfolioApp(name: "A", tagline: "", appStoreID: "1", icon: .systemName("a.circle")),
    ///     PortfolioApp(name: "B", tagline: "", appStoreID: "2", icon: .systemName("b.circle")),
    /// ]
    /// print(portfolio.excludingApp(withID: "1").map(\.name))   // ["B"]
    /// ```
    ///
    /// - Parameter id: The ``PortfolioApp/appStoreID`` to exclude.
    /// - Returns: An array without any app whose id matches.
    public func excludingApp(withID id: String) -> [PortfolioApp] {
        filter { $0.appStoreID != id }
    }
}
