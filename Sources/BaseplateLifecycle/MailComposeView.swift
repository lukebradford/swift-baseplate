#if canImport(MessageUI)
import MessageUI
import SwiftUI

/// A SwiftUI wrapper over `MFMailComposeViewController` for a "Send feedback" flow.
///
/// Present it in a `.sheet` only when ``canSendMail`` is `true`; otherwise show the
/// no-mail-available fallback (an alert, or a `mailto:` link) so the button never dead-ends on a
/// device with no mail account configured. The recipient, subject, and pre-filled body are all
/// configurable — pair it with ``DiagnosticsReport`` to seed an actionable body. The `onFinish`
/// closure fires when the user sends, cancels, or the compose fails; dismiss your sheet there.
///
/// This type is gated behind `#if canImport(MessageUI)`, so it does not exist on macOS; the
/// portable ``DiagnosticsReport`` builder does the testable work.
///
/// ```swift
/// struct FeedbackButton: View {
///     @State private var showMail = false
///     @State private var showNoMail = false
///     let report = DiagnosticsReport.current()
///     var body: some View {
///         Button("Send feedback") {
///             if MailComposeView.canSendMail { showMail = true } else { showNoMail = true }
///         }
///         .sheet(isPresented: $showMail) {
///             MailComposeView(
///                 recipient: "support@example.com",
///                 subject: report.emailSubject,
///                 body: report.emailBody
///             ) { showMail = false }
///         }
///         .alert("No email account", isPresented: $showNoMail) {
///             Button("OK", role: .cancel) {}
///         } message: {
///             Text("Configure an email account to send feedback.")
///         }
///     }
/// }
/// ```
public struct MailComposeView: UIViewControllerRepresentable {

    /// The recipient email address.
    public let recipient: String
    /// The email subject.
    public let subject: String
    /// The pre-filled body — typically ``DiagnosticsReport/emailBody``.
    public let body: String
    /// Invoked when the composer finishes (sent, cancelled, or failed). Dismiss the sheet here.
    public let onFinish: () -> Void

    /// Whether this device can send mail right now (an account is configured).
    ///
    /// Check this before presenting; when `false`, show the fallback instead.
    ///
    /// ```swift
    /// if MailComposeView.canSendMail { /* present */ }
    /// ```
    @MainActor
    public static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    /// Creates a mail-compose wrapper.
    ///
    /// ```swift
    /// let view = MailComposeView(
    ///     recipient: "support@example.com", subject: "Feedback", body: "…") {}
    /// ```
    ///
    /// - Parameters:
    ///   - recipient: The recipient email address.
    ///   - subject: The email subject.
    ///   - body: The pre-filled body.
    ///   - onFinish: Called when the composer finishes.
    public init(
        recipient: String,
        subject: String,
        body: String,
        onFinish: @escaping () -> Void
    ) {
        self.recipient = recipient
        self.subject = subject
        self.body = body
        self.onFinish = onFinish
    }

    /// Creates the configured `MFMailComposeViewController` (UIKit representable requirement).
    public func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([recipient])
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        return controller
    }

    /// No-op update; the composer is configured once at creation (representable requirement).
    public func updateUIViewController(
        _ controller: MFMailComposeViewController,
        context: Context
    ) {}

    /// Creates the delegate that forwards completion to ``onFinish`` (representable requirement).
    public func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    /// The mail-compose delegate that forwards completion to ``MailComposeView/onFinish``.
    public final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        /// Forwards the composer's completion (sent, cancelled, or failed) to ``onFinish``.
        public func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            onFinish()
        }
    }
}
#endif
