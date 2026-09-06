import Foundation
import Testing

@testable import BaseplateLifecycle

private func makeSuite() -> UserDefaults {
    let name = "review.\(UUID().uuidString)"
    let suite = UserDefaults(suiteName: name)!
    suite.removePersistentDomain(forName: name)
    return suite
}

/// A mutable, thread-safe clock for deterministic tests: set `now` and read it from a `@Sendable`
/// closure without tripping strict-concurrency capture rules.
private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date
    init(_ start: Date) { value = start }
    var now: Date {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }
}

@Suite struct ReviewPromptGateTests {

    @Test func does_not_fire_before_threshold() {
        let gate = ReviewPromptGate(minimumEvents: 3, defaults: makeSuite())
        gate.recordMeaningfulEvent()
        gate.recordMeaningfulEvent()
        #expect(gate.meaningfulEventCount == 2)
        #expect(gate.shouldRequestReview(appVersion: "1.0.0") == false)
    }

    @Test func fires_once_threshold_met() {
        let gate = ReviewPromptGate(minimumEvents: 2, defaults: makeSuite())
        gate.recordMeaningfulEvent()
        gate.recordMeaningfulEvent()
        #expect(gate.shouldRequestReview(appVersion: "1.0.0") == true)
    }

    @Test func fires_at_most_once_per_version() {
        let gate = ReviewPromptGate(minimumEvents: 1, defaults: makeSuite())
        gate.recordMeaningfulEvent()
        #expect(gate.shouldRequestReview(appVersion: "1.0.0") == true)
        gate.markRequested(appVersion: "1.0.0")
        #expect(gate.shouldRequestReview(appVersion: "1.0.0") == false)
    }

    @Test func re_arms_on_new_version() {
        let gate = ReviewPromptGate(minimumEvents: 1, defaults: makeSuite())
        gate.recordMeaningfulEvent()
        gate.markRequested(appVersion: "1.0.0")
        #expect(gate.shouldRequestReview(appVersion: "1.0.0") == false)
        #expect(gate.shouldRequestReview(appVersion: "1.1.0") == true)
    }

    @Test func first_launch_burst_is_gated_by_interval() {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let gate = ReviewPromptGate(
            minimumEvents: 1,
            minimumInterval: 60 * 60 * 24,  // one day
            defaults: makeSuite(),
            now: { clock.now }
        )
        // A burst of events on the first launch (t = 0) must NOT prompt.
        gate.recordMeaningfulEvent()
        gate.recordMeaningfulEvent()
        gate.recordMeaningfulEvent()
        #expect(gate.shouldRequestReview(appVersion: "1.0.0") == false)
        // A day later it is eligible.
        clock.now = Date(timeIntervalSince1970: 60 * 60 * 24)
        #expect(gate.shouldRequestReview(appVersion: "1.0.0") == true)
    }

    @Test func clock_moved_backward_does_not_prompt() {
        // firstEventDate is in the future relative to now → negative elapsed → not eligible.
        let result = ReviewPromptGate.shouldRequest(
            meaningfulEvents: 5,
            minimumEvents: 1,
            firstEventDate: Date(timeIntervalSince1970: 1000),
            now: Date(timeIntervalSince1970: 0),
            minimumInterval: 10,
            lastRequestedVersion: nil,
            appVersion: "1.0.0"
        )
        #expect(result == false)
    }

    @Test func pure_decision_all_gates_pass() {
        let result = ReviewPromptGate.shouldRequest(
            meaningfulEvents: 3,
            minimumEvents: 3,
            firstEventDate: nil,
            now: Date(),
            minimumInterval: nil,
            lastRequestedVersion: "0.9.0",
            appVersion: "1.0.0"
        )
        #expect(result == true)
    }

    @Test func recording_stamps_first_event_date_once() {
        let clock = TestClock(Date(timeIntervalSince1970: 100))
        let suite = makeSuite()
        let gate = ReviewPromptGate(defaults: suite, now: { clock.now })
        gate.recordMeaningfulEvent()
        let firstStamp = suite.object(forKey: "baseplate.review.firstEventDate") as? Date
        clock.now = Date(timeIntervalSince1970: 500)
        gate.recordMeaningfulEvent()
        let secondStamp = suite.object(forKey: "baseplate.review.firstEventDate") as? Date
        #expect(firstStamp == secondStamp)
        #expect(firstStamp == Date(timeIntervalSince1970: 100))
    }
}
