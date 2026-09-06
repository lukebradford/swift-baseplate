import Foundation

/// A pure, fully-injected value describing the app and device, formatted into a support-email body.
///
/// Support requests are far more actionable when they carry the app version, build, OS, device
/// model, and locale — but asking the user for those never works. This value assembles them into a
/// stable string you can pre-fill a feedback email with, leaving blank lines at the top for the
/// user to type into. Every input is injected, so ``emailBody`` is a deterministic function of its
/// fields and can be asserted against an exact string in tests. Nothing here reads `Bundle`,
/// `UIDevice`, or the ambient locale implicitly.
///
/// ```swift
/// let report = DiagnosticsReport(
///     appName: "Baseplate", appVersion: "1.4.0", buildNumber: "42",
///     systemName: "iOS", systemVersion: "17.5", deviceModel: "iPhone",
///     localeIdentifier: "en_US")
/// print(report.emailBody)
/// // (three blank lines, then)
/// // ———
/// // Baseplate 1.4.0 (42)
/// // iOS 17.5
/// // iPhone
/// // en_US
/// ```
public struct DiagnosticsReport: Sendable, Equatable {

    /// The app's display name, e.g. `"Baseplate"`.
    public var appName: String
    /// The marketing version, e.g. `"1.4.0"` (`CFBundleShortVersionString`).
    public var appVersion: String
    /// The build number, e.g. `"42"` (`CFBundleVersion`).
    public var buildNumber: String
    /// The OS name, e.g. `"iOS"`.
    public var systemName: String
    /// The OS version, e.g. `"17.5"`.
    public var systemVersion: String
    /// The device model description, e.g. `"iPhone"`.
    public var deviceModel: String
    /// The locale identifier, e.g. `"en_US"`.
    public var localeIdentifier: String

    /// Creates a diagnostics report from explicit values.
    ///
    /// ```swift
    /// let r = DiagnosticsReport(
    ///     appName: "App", appVersion: "1.0", buildNumber: "1",
    ///     systemName: "iOS", systemVersion: "17.0", deviceModel: "iPhone",
    ///     localeIdentifier: "en_US")
    /// ```
    ///
    /// - Parameters:
    ///   - appName: The app's display name.
    ///   - appVersion: The marketing version string.
    ///   - buildNumber: The build number string.
    ///   - systemName: The OS name.
    ///   - systemVersion: The OS version string.
    ///   - deviceModel: The device model description.
    ///   - localeIdentifier: The locale identifier.
    public init(
        appName: String,
        appVersion: String,
        buildNumber: String,
        systemName: String,
        systemVersion: String,
        deviceModel: String,
        localeIdentifier: String
    ) {
        self.appName = appName
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.systemName = systemName
        self.systemVersion = systemVersion
        self.deviceModel = deviceModel
        self.localeIdentifier = localeIdentifier
    }

    /// A suggested subject line, e.g. `"Baseplate feedback (1.4.0)"`.
    ///
    /// ```swift
    /// let r = DiagnosticsReport(
    ///     appName: "Baseplate", appVersion: "1.4.0", buildNumber: "42",
    ///     systemName: "iOS", systemVersion: "17.5", deviceModel: "iPhone",
    ///     localeIdentifier: "en_US")
    /// print(r.emailSubject)   // "Baseplate feedback (1.4.0)"
    /// ```
    public var emailSubject: String {
        "\(appName) feedback (\(appVersion))"
    }

    /// The pre-filled support-email body: three blank lines to type into, a separator, then the
    /// diagnostics block.
    ///
    /// The exact layout (asserted in tests) is:
    /// ```text
    /// \n\n\n———\n<appName> <appVersion> (<buildNumber>)\n<systemName> <systemVersion>\n<deviceModel>\n<localeIdentifier>
    /// ```
    ///
    /// ```swift
    /// let r = DiagnosticsReport(
    ///     appName: "App", appVersion: "1.0", buildNumber: "1",
    ///     systemName: "iOS", systemVersion: "17.0", deviceModel: "iPhone",
    ///     localeIdentifier: "en_US")
    /// print(r.emailBody.hasPrefix("\n\n\n———\n"))   // true
    /// ```
    public var emailBody: String {
        let lines = [
            "———",
            "\(appName) \(appVersion) (\(buildNumber))",
            "\(systemName) \(systemVersion)",
            deviceModel,
            localeIdentifier,
        ]
        return "\n\n\n" + lines.joined(separator: "\n")
    }
}

#if canImport(UIKit)
import UIKit

extension DiagnosticsReport {
    /// Builds a report from the live `Bundle`, `UIDevice`, and `Locale` (iOS/UIKit only).
    ///
    /// This is the non-deterministic convenience for production use; unit tests construct a
    /// ``DiagnosticsReport`` with explicit values via ``init(appName:appVersion:buildNumber:systemName:systemVersion:deviceModel:localeIdentifier:)``
    /// instead.
    ///
    /// ```swift
    /// let report = await DiagnosticsReport.current()
    /// ```
    ///
    /// - Parameters:
    ///   - bundle: The bundle to read app name/version/build from. Defaults to `.main`.
    ///   - device: The device to read model/OS from. Defaults to `.current`.
    ///   - locale: The locale to report. Defaults to `.current`.
    /// - Returns: A report populated from the running environment.
    /// - Note: Runs on the main actor because `UIDevice.current` is main-actor isolated.
    @MainActor
    public static func current(
        bundle: Bundle = .main,
        device: UIDevice = .current,
        locale: Locale = .current
    ) -> DiagnosticsReport {
        func info(_ key: String) -> String {
            bundle.object(forInfoDictionaryKey: key) as? String ?? "—"
        }
        let name =
            info("CFBundleDisplayName") == "—" ? info("CFBundleName") : info("CFBundleDisplayName")
        return DiagnosticsReport(
            appName: name,
            appVersion: info("CFBundleShortVersionString"),
            buildNumber: info("CFBundleVersion"),
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            deviceModel: device.model,
            localeIdentifier: locale.identifier
        )
    }
}
#endif
