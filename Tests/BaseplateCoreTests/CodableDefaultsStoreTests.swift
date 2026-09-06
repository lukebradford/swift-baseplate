import Foundation
import Testing

@testable import BaseplateCore

@Suite struct CodableDefaultsStoreTests {

    struct Draft: Codable, Sendable, Equatable {
        var text: String
        var count: Int
    }

    /// A mutable clock a test can advance, exposed as an injectable `@Sendable () -> Date`.
    ///
    /// `@unchecked Sendable`: test-only holder mutated single-threaded within one test.
    final class MutableClock: @unchecked Sendable {
        var date: Date
        init(_ date: Date) { self.date = date }
        var now: @Sendable () -> Date { { self.date } }
    }

    /// A fresh, isolated defaults suite plus its cleanup, so tests never touch `.standard`.
    private func makeDefaults() -> UserDefaults {
        let name = "CodableDefaultsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func save_then_load_round_trips() {
        let defaults = makeDefaults()
        let store = CodableDefaultsStore<Draft>(key: "k", schemaVersion: 1, defaults: defaults)
        let value = Draft(text: "hello", count: 3)
        store.save(value)
        #expect(store.load() == value)
    }

    @Test func load_is_nil_when_empty() {
        let defaults = makeDefaults()
        let store = CodableDefaultsStore<Draft>(key: "k", schemaVersion: 1, defaults: defaults)
        #expect(store.load() == nil)
    }

    @Test func incompatible_schema_is_discarded() {
        let defaults = makeDefaults()
        let v1 = CodableDefaultsStore<Draft>(key: "k", schemaVersion: 1, defaults: defaults)
        v1.save(Draft(text: "x", count: 1))

        let v2 = CodableDefaultsStore<Draft>(key: "k", schemaVersion: 2, defaults: defaults)
        #expect(v2.load() == nil)
        // Self-cleaned: the raw bytes are gone.
        #expect(defaults.data(forKey: "k") == nil)
    }

    @Test func corrupt_data_is_discarded_and_removed() {
        let defaults = makeDefaults()
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: "k")  // not valid JSON envelope
        let store = CodableDefaultsStore<Draft>(key: "k", schemaVersion: 1, defaults: defaults)
        #expect(store.load() == nil)
        #expect(defaults.data(forKey: "k") == nil)
    }

    @Test func value_older_than_max_age_is_discarded() {
        let defaults = makeDefaults()
        let clock = MutableClock(Date(timeIntervalSince1970: 1000))
        let store = CodableDefaultsStore<Draft>(
            key: "k", schemaVersion: 1, maxAge: 3600, defaults: defaults, now: clock.now
        )
        store.save(Draft(text: "x", count: 1))
        // Two hours later, past the one-hour window.
        clock.date = clock.date.addingTimeInterval(7200)
        #expect(store.load() == nil)
        #expect(defaults.data(forKey: "k") == nil)
    }

    @Test func value_within_max_age_survives() {
        let defaults = makeDefaults()
        let clock = MutableClock(Date(timeIntervalSince1970: 1000))
        let store = CodableDefaultsStore<Draft>(
            key: "k", schemaVersion: 1, maxAge: 3600, defaults: defaults, now: clock.now
        )
        store.save(Draft(text: "x", count: 1))
        clock.date = clock.date.addingTimeInterval(1800)  // half an hour later
        #expect(store.load() == Draft(text: "x", count: 1))
    }

    @Test func future_timestamp_means_clock_moved_backward_and_is_discarded() {
        let defaults = makeDefaults()
        let clock = MutableClock(Date(timeIntervalSince1970: 10_000))
        let store = CodableDefaultsStore<Draft>(
            key: "k", schemaVersion: 1, defaults: defaults, now: clock.now
        )
        store.save(Draft(text: "x", count: 1))
        // Clock jumped backward: the saved value is now stamped "in the future".
        clock.date = Date(timeIntervalSince1970: 5000)
        #expect(store.load() == nil)
        #expect(defaults.data(forKey: "k") == nil)
    }

    @Test func clear_removes_the_value() {
        let defaults = makeDefaults()
        let store = CodableDefaultsStore<Draft>(key: "k", schemaVersion: 1, defaults: defaults)
        store.save(Draft(text: "x", count: 1))
        store.clear()
        #expect(store.load() == nil)
    }
}
