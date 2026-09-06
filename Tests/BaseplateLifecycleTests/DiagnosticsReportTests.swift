import Foundation
import Testing

@testable import BaseplateLifecycle

@Suite struct DiagnosticsReportTests {

    private var sample: DiagnosticsReport {
        DiagnosticsReport(
            appName: "Baseplate",
            appVersion: "1.4.0",
            buildNumber: "42",
            systemName: "iOS",
            systemVersion: "17.5",
            deviceModel: "iPhone",
            localeIdentifier: "en_US"
        )
    }

    @Test func email_body_is_exact() {
        let expected =
            "\n\n\n———\nBaseplate 1.4.0 (42)\niOS 17.5\niPhone\nen_US"
        #expect(sample.emailBody == expected)
    }

    @Test func email_body_starts_with_three_blank_lines() {
        #expect(sample.emailBody.hasPrefix("\n\n\n———\n"))
    }

    @Test func subject_includes_name_and_version() {
        #expect(sample.emailSubject == "Baseplate feedback (1.4.0)")
    }

    @Test func empty_fields_produce_stable_body() {
        let report = DiagnosticsReport(
            appName: "", appVersion: "", buildNumber: "",
            systemName: "", systemVersion: "", deviceModel: "", localeIdentifier: "")
        // appName + " " + appVersion + " (" + build + ")" with all empty → "  ()" (two spaces).
        #expect(report.emailBody == "\n\n\n———\n  ()\n \n\n")
    }

    @Test func value_equality() {
        #expect(sample == sample)
    }
}
