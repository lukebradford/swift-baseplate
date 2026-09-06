import Foundation
import Testing

@testable import BaseplateUI

@Suite struct HapticsPreferenceTests {

    /// A fresh, isolated in-memory `UserDefaults` suite; removed after use so tests don't leak.
    private func makeDefaults(
        _ function: String = #function
    ) -> (UserDefaults, () -> Void) {
        let name = "HapticsPreferenceTests.\(function)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (defaults, { defaults.removePersistentDomain(forName: name) })
    }

    @Test func defaults_to_on_for_a_fresh_install() {
        let (defaults, teardown) = makeDefaults()
        defer { teardown() }

        let pref = HapticsPreference(defaults: defaults, key: "k")
        #expect(pref.isEnabled == true)
    }

    @Test func persists_disabled_state() {
        let (defaults, teardown) = makeDefaults()
        defer { teardown() }

        let pref = HapticsPreference(defaults: defaults, key: "k")
        pref.setEnabled(false)
        #expect(pref.isEnabled == false)

        // A fresh instance over the same store reads the persisted value.
        let reloaded = HapticsPreference(defaults: defaults, key: "k")
        #expect(reloaded.isEnabled == false)
    }

    @Test func re_enabling_after_disabling_reads_back_true() {
        let (defaults, teardown) = makeDefaults()
        defer { teardown() }

        let pref = HapticsPreference(defaults: defaults, key: "k")
        pref.setEnabled(false)
        pref.setEnabled(true)
        #expect(pref.isEnabled == true)
    }

    @Test func distinct_keys_do_not_interfere() {
        let (defaults, teardown) = makeDefaults()
        defer { teardown() }

        let a = HapticsPreference(defaults: defaults, key: "a")
        let b = HapticsPreference(defaults: defaults, key: "b")
        a.setEnabled(false)
        #expect(a.isEnabled == false)
        #expect(b.isEnabled == true)  // untouched key still defaults on
    }

    @Test func an_unrelated_non_bool_stored_value_reads_as_present_and_false() {
        // Simulates corrupt / wrong-typed data: object exists but isn't a usable Bool.
        let (defaults, teardown) = makeDefaults()
        defer { teardown() }

        defaults.set("garbage", forKey: "k")
        let pref = HapticsPreference(defaults: defaults, key: "k")
        // The key is present, so we do not fall through to the first-launch default;
        // `bool(forKey:)` coerces a non-numeric string to false.
        #expect(pref.isEnabled == false)
    }
}
