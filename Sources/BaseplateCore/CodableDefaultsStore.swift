import Foundation

/// Persists exactly one `Codable` value to `UserDefaults` as JSON, discarding it automatically
/// when it is incompatible, stale, corrupt, or dated in the future.
///
/// This is the store for a single snapshot-like value — an in-progress game, a cached response, a
/// draft — where a *wrong* restore is worse than no restore. Every load is validated against four
/// guards and the entry is deleted the moment any of them fails, so bad data can never be retried
/// forever:
///
/// - **Schema:** an explicit ``schemaVersion`` is written alongside the value; a value written by a
///   different schema is discarded (the format changed, the old bytes are meaningless).
/// - **Corruption:** bytes that no longer decode are discarded.
/// - **Age:** if a ``maxAge`` is set, a value older than it is discarded (a game left overnight is
///   not one you want back).
/// - **Future timestamp:** a value stamped *ahead* of "now" means the device clock moved backward,
///   so its true age is unknowable — it is discarded.
///
/// Every side effect is injected: the `UserDefaults` instance and the `now` clock. Tests use an
/// in-memory `UserDefaults(suiteName:)` and a fixed date, with no wall clock and no real storage.
///
/// ```swift
/// struct Draft: Codable, Sendable { var text: String }
///
/// let defaults = UserDefaults(suiteName: "example")!
/// var clock = Date(timeIntervalSince1970: 1000)
/// let store = CodableDefaultsStore<Draft>(
///     key: "draft", schemaVersion: 1, maxAge: 3600,
///     defaults: defaults, now: { clock }
/// )
///
/// store.save(Draft(text: "hello"))
/// print(store.load()?.text ?? "—")   // "hello"
/// clock = clock.addingTimeInterval(7200)   // now well past maxAge
/// print(store.load()?.text ?? "—")   // "—"  (expired and self-cleaned)
/// ```
public struct CodableDefaultsStore<Value: Codable & Sendable>: @unchecked Sendable {
    // @unchecked Sendable: the only reference-type field is `UserDefaults`, which Apple documents
    // as thread-safe but does not annotate `Sendable`; every other field is a value type or
    // `@Sendable`.

    /// A version-and-timestamp-stamped wrapper around the persisted value.
    private struct Envelope: Codable {
        let schemaVersion: Int
        let savedAt: Date
        let value: Value
    }

    /// The `UserDefaults` key the JSON is stored under.
    public let key: String

    /// The schema version stamped on writes and required on reads. Bump it when `Value`'s shape
    /// changes incompatibly to make every older entry self-discard.
    public let schemaVersion: Int

    /// The maximum age a stored value may reach before it is discarded on load, or `nil` for no
    /// age limit.
    public let maxAge: TimeInterval?

    private let defaults: UserDefaults
    private let now: @Sendable () -> Date

    /// Creates a store bound to a key, schema, and (optional) freshness window.
    ///
    /// ```swift
    /// let store = CodableDefaultsStore<[Int]>(key: "recent", schemaVersion: 2)
    /// store.save([1, 2, 3])
    /// print(store.load() ?? [])   // [1, 2, 3]
    /// ```
    ///
    /// - Parameters:
    ///   - key: The `UserDefaults` key to read and write.
    ///   - schemaVersion: The current schema version; a value stored under a different version is
    ///     discarded on load.
    ///   - maxAge: How long a value stays loadable, in seconds. `nil` (the default) means no limit.
    ///   - defaults: The backing store. Defaults to `.standard`; inject a suite in tests.
    ///   - now: The current-time source. Defaults to `Date()`; inject a fixed clock in tests.
    /// - Precondition: `maxAge`, when non-`nil`, should be `> 0`.
    public init(
        key: String,
        schemaVersion: Int,
        maxAge: TimeInterval? = nil,
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.key = key
        self.schemaVersion = schemaVersion
        self.maxAge = maxAge
        self.defaults = defaults
        self.now = now
    }

    /// Persists `value`, stamping it with the current schema version and the current time.
    ///
    /// A previously stored value under the same key is replaced. If encoding fails the store is
    /// left unchanged (it never writes partial data).
    ///
    /// ```swift
    /// let store = CodableDefaultsStore<String>(key: "greeting", schemaVersion: 1)
    /// store.save("hi")
    /// print(store.load() ?? "—")   // "hi"
    /// ```
    ///
    /// - Parameter value: The value to persist.
    public func save(_ value: Value) {
        let envelope = Envelope(schemaVersion: schemaVersion, savedAt: now(), value: value)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        defaults.set(data, forKey: key)
    }

    /// Returns the stored value, or `nil` if there is none or it fails any freshness guard.
    ///
    /// This method is self-cleaning: any stored value that is corrupt, from a different schema,
    /// older than ``maxAge``, or stamped in the future is removed from `UserDefaults` before `nil`
    /// is returned, so it cannot be retried on a later launch.
    ///
    /// ```swift
    /// let store = CodableDefaultsStore<Int>(key: "n", schemaVersion: 1)
    /// print(store.load() ?? -1)   // -1  (nothing stored yet)
    /// store.save(7)
    /// print(store.load() ?? -1)   // 7
    /// ```
    ///
    /// - Returns: The valid stored value, or `nil`.
    public func load() -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }

        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
            envelope.schemaVersion == schemaVersion
        else {
            defaults.removeObject(forKey: key)  // corrupt or incompatible schema
            return nil
        }

        let age = now().timeIntervalSince(envelope.savedAt)
        if age < 0 {
            defaults.removeObject(forKey: key)  // stamped in the future: clock moved backward
            return nil
        }
        if let maxAge, age > maxAge {
            defaults.removeObject(forKey: key)  // stale
            return nil
        }

        return envelope.value
    }

    /// Removes any stored value for this key.
    ///
    /// ```swift
    /// let store = CodableDefaultsStore<Int>(key: "n", schemaVersion: 1)
    /// store.save(1)
    /// store.clear()
    /// print(store.load() ?? -1)   // -1
    /// ```
    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
