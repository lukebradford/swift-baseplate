#if canImport(UIKit)
import SwiftUI
import Testing
import UIKit

@testable import BaseplateUI

/// Smoke tests for the UIKit-gated surface. These compile and run only where UIKit exists
/// (iOS simulator); the portable macOS build skips the whole file. The deterministic value
/// logic each type depends on is covered by the portable suites.
@MainActor
@Suite struct UIKitViewTests {

    @Test func shareable_image_gives_each_wrapper_a_distinct_identity() {
        let image = UIImage()
        let a = ShareableImage(image: image)
        let b = ShareableImage(image: image)
        #expect(a.id != b.id)
    }

    @Test func share_sheet_retains_its_items_and_callback() {
        var received: (String, Bool)?
        let sheet = ShareSheet(items: ["hello"]) { activity, completed in
            received = (activity, completed)
        }
        #expect(sheet.items.count == 1)
        #expect(sheet.onComplete != nil)
        sheet.onComplete?("test.activity", true)
        #expect(received?.0 == "test.activity")
        #expect(received?.1 == true)
    }

    @Test func exported_image_renders_a_non_empty_bitmap() {
        let view = Color.red.frame(width: 20, height: 20)
        let image = view.exportedAsImage(scale: 1)
        #expect(image != nil)
        #expect((image?.size.width ?? 0) > 0)
    }

    @Test func adaptive_uicolor_resolves_per_interface_style() {
        let color = UIColor.adaptive(light: .white, dark: .black)
        let light = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))

        var lightWhite: CGFloat = 0
        light.getWhite(&lightWhite, alpha: nil)
        var darkWhite: CGFloat = 1
        dark.getWhite(&darkWhite, alpha: nil)
        #expect(lightWhite > 0.9)  // resolves toward white in light mode
        #expect(darkWhite < 0.1)  // resolves toward black in dark mode
    }

    @Test func haptics_reports_the_injected_preference_and_no_ops_when_disabled() {
        let name = "UIKitViewTests.haptics"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        let pref = HapticsPreference(defaults: defaults, key: "k")
        pref.setEnabled(false)
        let haptics = Haptics(preference: pref)
        #expect(haptics.isEnabled == false)
        haptics.impact(.light)  // no-op while disabled; must not crash
    }
}
#endif
