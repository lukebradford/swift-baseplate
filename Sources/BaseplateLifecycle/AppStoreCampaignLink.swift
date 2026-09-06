import Foundation

/// Builds attributable App Store links carrying campaign parameters (`pt` / `ct` / `mt`).
///
/// The App Store campaign token (`ct`) is the only mechanism by which App Store Connect attributes
/// an install to a surface you control (a share caption, a cross-promotion row). This builder
/// produces a storefront-agnostic URL of the form:
///
/// ```text
/// https://apps.apple.com/app/id<APPSTORE_ID>?pt=<PROVIDER>&ct=<CAMPAIGN>&mt=8
/// ```
///
/// `mt=8` (mobile software apps) is always present. The provider token (`pt`, your developer
/// account's Provider Token from App Store Connect → App Analytics → Campaigns) is injected once and
/// omitted entirely when unset — the link still opens the correct page, it simply is not
/// attributable. The campaign token (`ct`) is sanitized to Apple's contract: whitespace becomes
/// underscores and it is truncated to 40 characters. No storefront path (`/us/`) or title slug is
/// included, so Apple redirects the bare id link to the viewer's own storefront.
///
/// ```swift
/// let builder = AppStoreCampaignLink(providerToken: "264080")
/// let url = builder.url(appStoreID: "327084738", campaignToken: "ios share sheet")
/// print(url.absoluteString)
/// // https://apps.apple.com/app/id327084738?pt=264080&ct=ios_share_sheet&mt=8
/// ```
///
/// - Precondition: `appStoreID` is non-empty.
public struct AppStoreCampaignLink: Sendable, Equatable {

    /// The developer account's Provider Token (`pt`), or `nil` when attribution is not configured.
    public var providerToken: String?

    /// Creates a campaign-link builder.
    ///
    /// ```swift
    /// let builder = AppStoreCampaignLink(providerToken: "264080")
    /// ```
    ///
    /// - Parameter providerToken: The `pt` value. Pass `nil` (the default) to omit `pt` and ship a
    ///   working-but-unattributable link.
    public init(providerToken: String? = nil) {
        self.providerToken = providerToken
    }

    /// `true` when a non-empty ``providerToken`` is set, so emitted links are attributable.
    ///
    /// ```swift
    /// print(AppStoreCampaignLink().attributionConfigured)               // false
    /// print(AppStoreCampaignLink(providerToken: "1").attributionConfigured)  // true
    /// ```
    public var attributionConfigured: Bool {
        !(providerToken ?? "").isEmpty
    }

    /// Builds the App Store URL for a numeric app id and optional campaign token.
    ///
    /// ```swift
    /// let url = AppStoreCampaignLink().url(appStoreID: "327084738")
    /// print(url.absoluteString)   // https://apps.apple.com/app/id327084738?mt=8
    /// ```
    ///
    /// - Parameters:
    ///   - appStoreID: The numeric App Store id (digits only, as a string).
    ///   - campaignToken: The campaign token (`ct`), sanitized before use. Defaults to `nil`.
    /// - Returns: A valid App Store URL. Built with `URLComponents`, so any reserved characters in
    ///   the provider or campaign token are percent-encoded rather than corrupting the query; never
    ///   crashes on malformed input.
    /// - Precondition: `appStoreID` is non-empty.
    public func url(appStoreID: String, campaignToken: String? = nil) -> URL {
        precondition(!appStoreID.isEmpty, "appStoreID must be non-empty")
        var components = URLComponents()
        components.scheme = "https"
        components.host = "apps.apple.com"
        components.path = "/app/id\(appStoreID)"
        var items: [URLQueryItem] = []
        if let providerToken, !providerToken.isEmpty {
            items.append(URLQueryItem(name: "pt", value: providerToken))
        }
        let ct = Self.sanitizedCampaignToken(campaignToken)
        if !ct.isEmpty {
            items.append(URLQueryItem(name: "ct", value: ct))
        }
        items.append(URLQueryItem(name: "mt", value: "8"))
        components.queryItems = items
        // `components.url` is non-nil for real (digits-only) ids; the fallbacks keep this total and
        // crash-free even if a caller violates the digits-only contract.
        return components.url
            ?? URL(string: "https://apps.apple.com/app/id\(appStoreID)")
            ?? URL(string: "https://apps.apple.com")!
    }

    /// Builds the App Store URL for a ``PortfolioApp``, using its ``PortfolioApp/campaignToken``.
    ///
    /// ```swift
    /// let app = PortfolioApp(
    ///     name: "A", tagline: "", appStoreID: "327084738",
    ///     icon: .systemName("a.circle"), campaignToken: "cross_promo")
    /// let url = AppStoreCampaignLink(providerToken: "264080").url(for: app)
    /// print(url.absoluteString)
    /// // https://apps.apple.com/app/id327084738?pt=264080&ct=cross_promo&mt=8
    /// ```
    ///
    /// - Parameter app: The portfolio app to link to.
    /// - Returns: A valid App Store URL for the app.
    public func url(for app: PortfolioApp) -> URL {
        url(appStoreID: app.appStoreID, campaignToken: app.campaignToken)
    }

    /// Sanitizes a campaign token to Apple's contract: whitespace → `_`, truncated to 40 characters.
    ///
    /// A `nil` or empty token yields `""` (the caller omits `ct` entirely).
    ///
    /// ```swift
    /// print(AppStoreCampaignLink.sanitizedCampaignToken("ios share sheet"))  // "ios_share_sheet"
    /// ```
    ///
    /// - Parameter token: The raw campaign token, or `nil`.
    /// - Returns: The sanitized token, or `""` when there is nothing usable.
    public static func sanitizedCampaignToken(_ token: String?) -> String {
        guard let token, !token.isEmpty else { return "" }
        let collapsed =
            token
            .components(separatedBy: .whitespacesAndNewlines)
            .joined(separator: "_")
        return String(collapsed.prefix(40))
    }
}
