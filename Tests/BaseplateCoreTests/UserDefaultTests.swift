import Foundation
import Testing

@testable import BaseplateCore

@Suite struct UserDefaultTests {

    enum Theme: String, Sendable { case light, dark, midnight }

    private func makeDefaults() -> UserDefaults {
        let name = "UserDefaultTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func returns_default_when_absent() {
        let defaults = makeDefaults()
        let flag = UserDefault(wrappedValue: true, "flag", store: defaults)
        #expect(flag.wrappedValue == true)
    }

    @Test func persists_and_reads_back_a_value() {
        let defaults = makeDefaults()
        let count = UserDefault(wrappedValue: 0, "count", store: defaults)
        count.wrappedValue = 5
        #expect(count.wrappedValue == 5)
        // A fresh wrapper over the same store sees the persisted value.
        let reread = UserDefault(wrappedValue: 0, "count", store: defaults)
        #expect(reread.wrappedValue == 5)
    }

    @Test func raw_representable_enum_round_trips() {
        let defaults = makeDefaults()
        let theme = UserDefault(wrappedValue: Theme.light, "theme", store: defaults)
        theme.wrappedValue = .dark
        #expect(theme.wrappedValue == .dark)
    }

    @Test func unknown_stored_raw_value_falls_back_to_default() {
        let defaults = makeDefaults()
        // Simulate a downgrade: a raw value this build's enum no longer has.
        defaults.set("aurora", forKey: "theme")
        let theme = UserDefault(wrappedValue: Theme.light, "theme", store: defaults)
        #expect(theme.wrappedValue == .light)
    }

    @Test func wrong_typed_stored_value_falls_back_to_default() {
        let defaults = makeDefaults()
        defaults.set("not a number", forKey: "count")
        let count = UserDefault(wrappedValue: 42, "count", store: defaults)
        #expect(count.wrappedValue == 42)
    }

    @Test func reset_restores_the_default() {
        let defaults = makeDefaults()
        let flag = UserDefault(wrappedValue: false, "flag", store: defaults)
        flag.wrappedValue = true
        flag.reset()
        #expect(flag.wrappedValue == false)
    }

    @Test func projected_value_exposes_key() {
        let defaults = makeDefaults()
        let flag = UserDefault(wrappedValue: false, "my.key", store: defaults)
        #expect(flag.projectedValue.key == "my.key")
    }

    @Test func first_run_seeding_pattern() {
        // The Settings.swift pattern: seed a default only on first launch.
        let defaults = makeDefaults()
        let hasLaunched = UserDefault(wrappedValue: false, "hasLaunched", store: defaults)
        let capitalize = UserDefault(wrappedValue: false, "capitalize", store: defaults)
        if !hasLaunched.wrappedValue {
            capitalize.wrappedValue = true  // one-time seed
        }
        hasLaunched.wrappedValue = true
        #expect(capitalize.wrappedValue == true)
        #expect(hasLaunched.wrappedValue == true)
    }
}
