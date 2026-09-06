import SwiftUI

/// A SwiftUI list of ``PortfolioApp`` rows for a "More apps from the developer" section.
///
/// Generic and portfolio-free: you pass the apps to show and a closure invoked when a row is tapped
/// (typically opening an ``AppStoreCampaignLink`` URL via the `openURL` environment action). Each
/// row shows the app's icon, name, and tagline. Filter the list with
/// ``Swift/Sequence/excludingApp(withID:)`` first to avoid advertising the current app.
///
/// ```swift
/// struct MoreApps: View {
///     @Environment(\.openURL) private var openURL
///     let apps: [PortfolioApp]
///     let links = AppStoreCampaignLink(providerToken: "264080")
///     var body: some View {
///         CrossPromoShelf(apps: apps) { app in
///             openURL(links.url(for: app))
///         }
///     }
/// }
/// ```
public struct CrossPromoShelf: View {

    private let apps: [PortfolioApp]
    private let onOpen: (PortfolioApp) -> Void

    /// Creates a cross-promotion shelf.
    ///
    /// ```swift
    /// let shelf = CrossPromoShelf(apps: []) { _ in }
    /// ```
    ///
    /// - Parameters:
    ///   - apps: The apps to render, in display order.
    ///   - onOpen: Invoked with the tapped app; open its App Store URL here.
    public init(apps: [PortfolioApp], onOpen: @escaping (PortfolioApp) -> Void) {
        self.apps = apps
        self.onOpen = onOpen
    }

    /// The rendered rows — one tappable ``PortfolioApp`` row per app, in order.
    public var body: some View {
        ForEach(apps) { app in
            Button {
                onOpen(app)
            } label: {
                CrossPromoRow(app: app)
            }
            .buttonStyle(.plain)
        }
    }
}

/// A single row: icon, name, tagline, and a trailing chevron. Internal to ``CrossPromoShelf``.
private struct CrossPromoRow: View {
    let app: PortfolioApp

    private static let iconSize: CGFloat = 40

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: Self.iconSize, height: Self.iconSize)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(app.tagline)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(app.name). \(app.tagline)")
    }

    @ViewBuilder
    private var icon: some View {
        switch app.icon {
        case .systemName(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .padding(6)
                .foregroundStyle(.tint)
        case .url(let url):
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.quaternary)
            }
        }
    }
}
