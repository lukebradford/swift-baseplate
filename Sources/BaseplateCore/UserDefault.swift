import Foundation

/// A property wrapper that reads and writes a single typed value in `UserDefaults`, returning a
/// caller-supplied default when nothing is stored (or the stored value no longer fits the type).
///
/// It removes the boilerplate of `object(forKey:) as? T ?? fallback` on every setting, keeps the
/// key and default next to the property, and — crucially — lets you inject the `UserDefaults`
/// instance so settings code is testable against an in-memory suite instead of the shared store.
///
/// Two flavors are selected automatically by the value type:
/// - **Property-list values** (`Bool`, `Int`, `Double`, `String`, `Data`, `Date`, arrays/dicts of
///   those, …): stored directly.
/// - **`RawRepresentable` values** (typically a `String`- or `Int`-backed `enum`): stored as the
///   raw value, and — the important part — a stored raw value this build no longer recognizes
///   (an enum case removed since it was written, e.g. after a downgrade or an iCloud restore)
///   falls back to the default instead of trapping or returning `nil`.
///
/// - Note: The setter is `nonmutating` (it writes through to the reference-type store), so a
///   wrapped property can be declared with `let`. For a *namespaced* key, compose the string
///   yourself (e.g. `"\(bundleID).textSize"`); the wrapper stores whatever key you give it.
///
/// ```swift
/// enum Theme: String { case light, dark }
///
/// struct Settings {
///     @UserDefault("hasLaunched", store: .standard) var hasLaunched = false
///     @UserDefault("theme", store: .standard) var theme = Theme.light
/// }
///
/// var settings = Settings()
/// settings.hasLaunched = true
/// print(settings.hasLaunched)   // true
/// ```
@propertyWrapper
public struct UserDefault<Value: Sendable>: @unchecked Sendable {
    // @unchecked Sendable: the only reference-type field is `UserDefaults`, which Apple documents
    // as thread-safe but does not annotate `Sendable`; every other field is a value type or
    // `@Sendable`.

    /// The `UserDefaults` key this property is stored under.
    public let key: String

    /// The value returned when nothing valid is stored for ``key``.
    public let defaultValue: Value

    private let store: UserDefaults
    private let read: @Sendable (UserDefaults, String, Value) -> Value
    private let write: @Sendable (UserDefaults, String, Value) -> Void

    /// The current value: the stored one if present and valid, otherwise ``defaultValue``.
    ///
    /// Reading consults `UserDefaults` each time (values may change underneath you); writing
    /// persists immediately.
    public var wrappedValue: Value {
        get { read(store, key, defaultValue) }
        nonmutating set { write(store, key, newValue) }
    }

    /// The wrapper itself, exposed via the `$` projection for callers that need the key or store.
    ///
    /// ```swift
    /// struct S { @UserDefault("count") var count = 0 }
    /// print(S().$count.key)   // "count"
    /// ```
    public var projectedValue: UserDefault<Value> { self }

    /// Creates a wrapper for a property-list-storable value.
    ///
    /// ```swift
    /// struct S { @UserDefault("launches") var launches = 0 }
    /// var s = S()
    /// s.launches += 1
    /// print(s.launches)   // 1
    /// ```
    ///
    /// - Parameters:
    ///   - defaultValue: The default returned when nothing is stored (supplied as the property's
    ///     initial value, e.g. `@UserDefault("k") var x = false`).
    ///   - key: The `UserDefaults` key.
    ///   - store: The backing store. Defaults to `.standard`; inject a suite in tests.
    public init(wrappedValue defaultValue: Value, _ key: String, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = store
        self.read = { store, key, fallback in
            store.object(forKey: key) as? Value ?? fallback
        }
        self.write = { store, key, value in
            store.set(value, forKey: key)
        }
    }

    /// Creates a wrapper for a `RawRepresentable` value (usually an `enum`), with an
    /// unknown-value fallback.
    ///
    /// The raw value is what gets persisted. On read, a stored raw value that does not map to any
    /// current case — because the enum shrank since it was written — resolves to `wrappedValue`
    /// rather than trapping, exactly the behavior a settings screen needs after a downgrade.
    ///
    /// ```swift
    /// enum Size: String { case small, large }
    /// struct S { @UserDefault("size") var size = Size.small }
    /// var s = S()
    /// s.size = .large
    /// print(s.size)   // large
    /// ```
    ///
    /// - Parameters:
    ///   - defaultValue: The default, also used as the fallback for an unrecognized stored raw
    ///     value (supplied as the property's initial value).
    ///   - key: The `UserDefaults` key.
    ///   - store: The backing store. Defaults to `.standard`; inject a suite in tests.
    public init(
        wrappedValue defaultValue: Value,
        _ key: String,
        store: UserDefaults = .standard
    ) where Value: RawRepresentable, Value.RawValue: Sendable {
        self.key = key
        self.defaultValue = defaultValue
        self.store = store
        self.read = { store, key, fallback in
            guard let raw = store.object(forKey: key) as? Value.RawValue,
                let value = Value(rawValue: raw)
            else {
                return fallback  // absent, wrong-typed, or an unknown/retired case
            }
            return value
        }
        self.write = { store, key, value in
            store.set(value.rawValue, forKey: key)
        }
    }

    /// Removes the stored value, so the next read returns ``defaultValue`` again.
    ///
    /// ```swift
    /// struct S { @UserDefault("flag") var flag = false }
    /// let s = S()
    /// s.flag = true
    /// s.$flag.reset()
    /// print(s.flag)   // false
    /// ```
    public func reset() {
        store.removeObject(forKey: key)
    }
}
