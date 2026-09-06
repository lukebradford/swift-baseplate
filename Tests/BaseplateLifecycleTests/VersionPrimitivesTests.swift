import Foundation
import Testing

@testable import BaseplateLifecycle

private func makeSuite(_ tag: String) -> UserDefaults {
    let name = "\(tag).\(UUID().uuidString)"
    let suite = UserDefaults(suiteName: name)!
    suite.removePersistentDomain(forName: name)
    return suite
}

@Suite struct FirstLaunchTests {

    @Test func first_launch_true_then_false() {
        let fl = FirstLaunch(defaults: makeSuite("fl"))
        #expect(fl.isFirstLaunch == true)
        fl.markLaunched()
        #expect(fl.isFirstLaunch == false)
    }

    @Test func consume_fires_exactly_once() {
        let fl = FirstLaunch(defaults: makeSuite("fl"))
        #expect(fl.consume() == true)
        #expect(fl.consume() == false)
        #expect(fl.isFirstLaunch == false)
    }
}

@Suite struct VersionChangeTests {

    @Test func fresh_install_when_nothing_stored() {
        let vc = VersionChange(currentVersion: "1.0.0", defaults: makeSuite("vc"))
        #expect(vc.transition == .freshInstall)
    }

    @Test func upgrade_detected_after_commit() {
        let suite = makeSuite("vc")
        VersionChange(currentVersion: "1.0.0", defaults: suite).commit()
        let vc = VersionChange(currentVersion: "1.1.0", defaults: suite)
        #expect(vc.transition == .upgrade(from: "1.0.0", to: "1.1.0"))
    }

    @Test func unchanged_after_commit_same_version() {
        let suite = makeSuite("vc")
        VersionChange(currentVersion: "2.0.0", defaults: suite).commit()
        let vc = VersionChange(currentVersion: "2.0.0", defaults: suite)
        #expect(vc.transition == .unchanged("2.0.0"))
    }

    @Test func downgrade_detected_on_rollback() {
        let suite = makeSuite("vc")
        VersionChange(currentVersion: "2.0.0", defaults: suite).commit()
        let vc = VersionChange(currentVersion: "1.5.0", defaults: suite)
        #expect(vc.transition == .downgrade(from: "2.0.0", to: "1.5.0"))
    }

    @Test func numeric_component_ordering() {
        // "1.10.0" is newer than "1.9.0" (numeric, not lexicographic).
        #expect(
            VersionChange.classify(current: "1.10.0", lastSeen: "1.9.0")
                == .upgrade(from: "1.9.0", to: "1.10.0"))
    }

    @Test func numerically_equal_but_differently_written_is_unchanged() {
        // "1.0" and "1.0.0" differ as strings but are numerically equal, so the numeric compare is
        // `orderedSame`: this must classify as `.unchanged` (NOT a spurious downgrade that would
        // fire downgrade-only UI or, worse, re-run first-run logic on a re-formatted version string).
        let t = VersionChange.classify(current: "1.0.0", lastSeen: "1.0")
        #expect(t == .unchanged("1.0.0"))
        if case .upgrade = t { Issue.record("must not be classified as an upgrade") }
        if case .downgrade = t {
            Issue.record("numerically-equal versions must not be a downgrade")
        }
    }
}

@Suite struct ShowOnceFlagTests {

    @Test func ever_shows_once() {
        let flag = ShowOnceFlag(key: "tip", scope: .ever, defaults: makeSuite("sof"))
        #expect(flag.shouldShow == true)
        flag.markShown()
        #expect(flag.shouldShow == false)
    }

    @Test func per_version_rearms_on_new_version() {
        let suite = makeSuite("sof")
        let v1 = ShowOnceFlag(
            key: "wn", scope: .perVersion, currentVersion: "1.0.0", defaults: suite)
        #expect(v1.shouldShow == true)
        v1.markShown()
        #expect(v1.shouldShow == false)
        let v2 = ShowOnceFlag(
            key: "wn", scope: .perVersion, currentVersion: "1.1.0", defaults: suite)
        #expect(v2.shouldShow == true)
    }

    @Test func reset_rearms() {
        let flag = ShowOnceFlag(key: "tip", defaults: makeSuite("sof"))
        flag.markShown()
        flag.reset()
        #expect(flag.shouldShow == true)
    }
}

@Suite struct WhatsNewGateTests {

    @Test func fresh_install_does_not_show_by_default() {
        let gate = WhatsNewGate(currentVersion: "1.0.0", defaults: makeSuite("wn"))
        #expect(gate.shouldShowWhatsNew == false)
    }

    @Test func fresh_install_shows_when_opted_in() {
        let gate = WhatsNewGate(
            currentVersion: "1.0.0", showOnFreshInstall: true, defaults: makeSuite("wn"))
        #expect(gate.shouldShowWhatsNew == true)
    }

    @Test func shows_once_on_upgrade() {
        let suite = makeSuite("wn")
        WhatsNewGate(currentVersion: "1.0.0", defaults: suite).markShown()
        let gate = WhatsNewGate(currentVersion: "1.1.0", defaults: suite)
        #expect(gate.shouldShowWhatsNew == true)
        gate.markShown()
        #expect(gate.shouldShowWhatsNew == false)
    }

    @Test func fresh_install_skipped_then_next_upgrade_shows() {
        let suite = makeSuite("wn")
        // Launch 1: fresh install of 1.0.0, skipped, baseline advanced.
        let launch1 = WhatsNewGate(currentVersion: "1.0.0", defaults: suite)
        #expect(launch1.shouldShowWhatsNew == false)
        launch1.markShown()
        // Launch 2: upgrade to 1.1.0 — release notes now show.
        let launch2 = WhatsNewGate(currentVersion: "1.1.0", defaults: suite)
        #expect(launch2.shouldShowWhatsNew == true)
    }

    @Test func downgrade_does_not_show() {
        let suite = makeSuite("wn")
        WhatsNewGate(currentVersion: "2.0.0", defaults: suite).markShown()
        let gate = WhatsNewGate(currentVersion: "1.0.0", defaults: suite)
        #expect(gate.shouldShowWhatsNew == false)
    }
}
