#if canImport(UIKit)
import UIKit

/// A pre-primed haptic feedback helper gated by a persisted user preference.
///
/// Wraps UIKit's impact, notification, and selection feedback generators, keeping them "primed"
/// (via `prepare()`) so the first tap after a quiet period fires with minimal latency. Every call
/// is gated by ``HapticsPreference`` — when the user has turned haptics off, calls are no-ops.
/// The type is `@MainActor` because `UIFeedbackGenerator` must be used from the main thread.
///
/// ```swift
/// import UIKit
///
/// @MainActor
/// func onTap(_ haptics: Haptics) {
///     haptics.impact(.light)      // fires only if the user has haptics enabled
///     haptics.selectionChanged()
/// }
/// ```
@MainActor
public final class Haptics {
    private let preference: HapticsPreference
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    /// Creates a haptics helper and primes its generators.
    ///
    /// ```swift
    /// import UIKit
    ///
    /// let haptics = MainActor.assumeIsolated { Haptics() }
    /// _ = haptics
    /// ```
    ///
    /// - Parameter preference: The on/off gate. Defaults to a `.standard`-backed
    ///   ``HapticsPreference``; inject one over a test suite to control it.
    public init(preference: HapticsPreference = HapticsPreference()) {
        self.preference = preference
        prepareAll()
    }

    /// Whether haptics are currently enabled by the user preference.
    ///
    /// ```swift
    /// import UIKit
    ///
    /// let haptics = MainActor.assumeIsolated { Haptics() }
    /// print(haptics.isEnabled)   // true on a fresh install
    /// ```
    public var isEnabled: Bool { preference.isEnabled }

    /// Fires an impact ("tap") of the given intensity, then re-primes for the next one.
    ///
    /// A no-op when the user has disabled haptics. `.light`, `.medium`, and `.heavy` reuse
    /// pre-primed generators; other styles create a generator on demand.
    ///
    /// ```swift
    /// import UIKit
    ///
    /// let haptics = MainActor.assumeIsolated { Haptics() }
    /// haptics.impact(.heavy)
    /// ```
    ///
    /// - Parameter style: The impact intensity. Defaults to `.medium`.
    public func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard preference.isEnabled else { return }
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light: generator = light
        case .medium: generator = medium
        case .heavy: generator = heavy
        default: generator = UIImpactFeedbackGenerator(style: style)
        }
        generator.impactOccurred()
        generator.prepare()
    }

    /// Fires a notification feedback (success / warning / error), then re-primes.
    ///
    /// A no-op when the user has disabled haptics.
    ///
    /// ```swift
    /// import UIKit
    ///
    /// let haptics = MainActor.assumeIsolated { Haptics() }
    /// haptics.notify(.success)
    /// ```
    ///
    /// - Parameter type: The notification feedback type.
    public func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard preference.isEnabled else { return }
        notification.notificationOccurred(type)
        notification.prepare()
    }

    /// Fires a selection-changed tick (as when moving across discrete values), then re-primes.
    ///
    /// A no-op when the user has disabled haptics.
    ///
    /// ```swift
    /// import UIKit
    ///
    /// let haptics = MainActor.assumeIsolated { Haptics() }
    /// haptics.selectionChanged()
    /// ```
    public func selectionChanged() {
        guard preference.isEnabled else { return }
        selection.selectionChanged()
        selection.prepare()
    }

    /// Persists a new enabled state; when enabling, re-primes and fires a confirming tap.
    ///
    /// ```swift
    /// import UIKit
    ///
    /// let haptics = MainActor.assumeIsolated { Haptics() }
    /// haptics.setEnabled(false)
    /// print(haptics.isEnabled)   // false
    /// ```
    ///
    /// - Parameter enabled: `true` to allow haptics, `false` to suppress them.
    public func setEnabled(_ enabled: Bool) {
        preference.setEnabled(enabled)
        if enabled {
            prepareAll()
            light.impactOccurred()
        }
    }

    private func prepareAll() {
        light.prepare()
        medium.prepare()
        heavy.prepare()
        notification.prepare()
        selection.prepare()
    }
}
#endif
