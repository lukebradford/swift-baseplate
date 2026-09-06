import BaseplateLifecycle

/// A concrete portfolio registry — the kind each adopter defines once and reuses in every app to
/// power its cross-promotion shelf. Baseplate ships the generic ``PortfolioApp`` /
/// ``CrossPromoShelf`` types but no hardcoded list, so this lives in Examples, not the library.
///
/// (App Store ids marked `TODO` are placeholders — swap in the real numeric id from each app's
/// store URL, e.g. the digits in `https://apps.apple.com/app/id6760784173`.)
enum LukePortfolio {
    static let all: [PortfolioApp] = [
        PortfolioApp(
            name: "Quarc",
            tagline: "A tactile falling-blocks puzzle.",
            appStoreID: "6760784173",
            icon: .systemName("circle.hexagongrid.fill"),
            campaignToken: "crosspromo"),
        PortfolioApp(
            name: "Megalith",
            tagline: "Turn a phrase into a block-justified graphic.",
            appStoreID: "0000000001",  // TODO: real App Store id
            icon: .systemName("character.textbox"),
            campaignToken: "crosspromo"),
        PortfolioApp(
            name: "Textile",
            tagline: "Notes with a sense of craft.",
            appStoreID: "0000000002",  // TODO: real App Store id
            icon: .systemName("doc.richtext"),
            campaignToken: "crosspromo"),
        PortfolioApp(
            name: "Symmetry Lab",
            tagline: "Draw with living kaleidoscopic symmetry.",
            appStoreID: "0000000003",  // TODO: real App Store id
            icon: .systemName("circle.grid.cross.fill"),
            campaignToken: "crosspromo"),
        PortfolioApp(
            name: "Waveboard",
            tagline: "A soundboard you play like an instrument.",
            appStoreID: "0000000004",  // TODO: real App Store id
            icon: .systemName("waveform"),
            campaignToken: "crosspromo"),
    ]
}
