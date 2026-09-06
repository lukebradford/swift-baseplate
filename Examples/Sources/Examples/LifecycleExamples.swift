import BaseplateLifecycle
import Foundation

/// A tour of `BaseplateLifecycle` — the indie app-lifecycle chores.
func lifecycleExamples() {
    let defaults = UserDefaults(suiteName: "examples.lifecycle")!

    // Ask for a review the right way: only after enough delight, at most once per version.
    let review = ReviewPromptGate(minimumEvents: 3, defaults: defaults)
    review.recordMeaningfulEvent()
    if review.shouldRequestReview(appVersion: "1.4.0") {
        // present SKStoreReviewController here; then:
        review.markRequested(appVersion: "1.4.0")
    }

    // Detect fresh install vs upgrade.
    let version = VersionChange(currentVersion: "2.0.0", defaults: defaults)
    _ = version.transition  // .freshInstall / .upgrade(from:) / .same
    version.commit()

    // A pre-filled support email carrying the diagnostics users never report accurately.
    let report = DiagnosticsReport(
        appName: "Baseplate", appVersion: "1.4.0", buildNumber: "42",
        systemName: "iOS", systemVersion: "17.5", deviceModel: "iPhone",
        localeIdentifier: "en_US")
    _ = report.emailSubject  // "Baseplate feedback (1.4.0)"
    _ = report.emailBody

    // Portfolio cross-promotion: one shared list, attributable App Store links.
    let others = LukePortfolio.all.excludingApp(withID: "6760784173")  // everything but Quarc
    let link = AppStoreCampaignLink(providerToken: "123456")
    if let first = others.first {
        _ = link.url(for: first)  // https://apps.apple.com/app/id…?pt=123456&ct=…&mt=8
    }
}
