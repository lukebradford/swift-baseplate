import Foundation

/// A deterministic `RandomNumberGenerator` (xorshift64) whose internal state can be read back
/// and restored, so a random sequence can be paused, snapshotted, and resumed bit-for-bit later.
///
/// Seed it once and every consumer that starts from the same seed sees the identical stream —
/// the property that makes tests reproducible and makes a "daily challenge" hand every player the
/// same board (see ``DailySeed``). Because the whole state is a single `UInt64` you can persist
/// ``state`` in a snapshot and rebuild an identical generator with ``init(state:)`` to keep the
/// sequence going across an app relaunch.
///
/// - Invariant: `state` is never zero. xorshift64 is stuck at zero forever once it reaches it, so
///   a zero seed (or a zero restored state) is remapped to a fixed non-zero constant. A `state`
///   read back from a live generator is therefore always safe to restore, and restoring it never
///   triggers the remap.
///
/// ```swift
/// var rng = SeededRandomNumberGenerator(seed: 42)
/// let a = UInt64.random(in: .min ... .max, using: &rng)
///
/// // Snapshot the state, keep drawing, then rewind to the snapshot:
/// let saved = rng.state
/// _ = UInt64.random(in: .min ... .max, using: &rng)
/// var resumed = SeededRandomNumberGenerator(state: saved)
/// // `resumed` now reproduces exactly what `rng` produced after `saved`.
/// print(a)
/// ```
public struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {

    /// The non-zero constant a zero seed/state collapses to (the golden-ratio odd constant).
    private static let nonZeroFallback: UInt64 = 0x9E37_79B9_7F4A_7C15

    /// The live internal state. Read it to snapshot the generator; restore it with ``init(state:)``.
    ///
    /// - Invariant: never zero (see the type's discussion).
    public private(set) var state: UInt64

    /// Creates a generator seeded with `seed`.
    ///
    /// ```swift
    /// var rng = SeededRandomNumberGenerator(seed: 1)
    /// print(Int.random(in: 0..<6, using: &rng))
    /// ```
    ///
    /// - Parameter seed: Any 64-bit seed. `0` is remapped to a fixed non-zero constant so the
    ///   generator can never be born in the dead zero state.
    public init(seed: UInt64) {
        state = seed == 0 ? Self.nonZeroFallback : seed
    }

    /// Restores a generator from a previously captured ``state``, resuming its sequence exactly.
    ///
    /// ```swift
    /// var rng = SeededRandomNumberGenerator(seed: 99)
    /// _ = rng.next()
    /// let resumed = SeededRandomNumberGenerator(state: rng.state)
    /// print(resumed.state == rng.state)   // true
    /// ```
    ///
    /// - Parameter state: A state value from another generator's ``state``. `0` is remapped to the
    ///   same non-zero constant ``init(seed:)`` uses, upholding the never-zero invariant.
    public init(state: UInt64) {
        self.state = state == 0 ? Self.nonZeroFallback : state
    }

    /// Advances the generator and returns the next 64 bits of output.
    ///
    /// ```swift
    /// var rng = SeededRandomNumberGenerator(seed: 7)
    /// let bits = rng.next()
    /// print(bits != 0)   // true
    /// ```
    ///
    /// - Returns: The next value in the xorshift64 sequence. Uniformly distributed over the full
    ///   `UInt64` range across a period of 2^64 − 1.
    public mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
