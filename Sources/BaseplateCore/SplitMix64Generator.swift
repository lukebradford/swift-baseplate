import Foundation

/// A deterministic `RandomNumberGenerator` (SplitMix64) with readable, restorable state.
///
/// SplitMix64 is a fast, well-distributed generator whose output passes standard statistical
/// tests. It complements ``SeededRandomNumberGenerator``: prefer this one when you want strong
/// scrambling of a low-entropy seed (a small counter, a day index, a row number), because a single
/// `next()` diffuses the input across all 64 output bits. Its ``state`` is a plain counter, so it
/// can be snapshotted and resumed just like the xorshift generator.
///
/// - Invariant: none needed. Unlike xorshift64, SplitMix64 has no dead state — a zero seed is a
///   perfectly valid starting point, so no remap is applied and ``state`` may legitimately be zero.
///
/// ```swift
/// var rng = SplitMix64Generator(seed: 0)          // zero is fine here
/// let value = Int.random(in: 1...100, using: &rng)
///
/// // State round-trips for snapshot/resume:
/// let saved = rng.state
/// let resumed = SplitMix64Generator(state: saved)
/// print(resumed.state == saved)                   // true
/// print(value >= 1 && value <= 100)               // true
/// ```
public struct SplitMix64Generator: RandomNumberGenerator, Sendable {

    private static let increment: UInt64 = 0x9E37_79B9_7F4A_7C15

    /// The live internal state (a running counter). Read it to snapshot; restore with ``init(state:)``.
    public private(set) var state: UInt64

    /// Creates a generator seeded with `seed`. Every seed value, including `0`, is valid.
    ///
    /// ```swift
    /// var rng = SplitMix64Generator(seed: 12345)
    /// print(rng.next() != 0)   // true
    /// ```
    ///
    /// - Parameter seed: Any 64-bit seed; used directly as the initial state.
    public init(seed: UInt64) {
        state = seed
    }

    /// Restores a generator from a previously captured ``state``, resuming its sequence exactly.
    ///
    /// ```swift
    /// var rng = SplitMix64Generator(seed: 5)
    /// _ = rng.next()
    /// let resumed = SplitMix64Generator(state: rng.state)
    /// print(resumed.state == rng.state)   // true
    /// ```
    ///
    /// - Parameter state: A state value from another generator's ``state``.
    public init(state: UInt64) {
        self.state = state
    }

    /// Advances the generator and returns the next 64 bits of output.
    ///
    /// ```swift
    /// var rng = SplitMix64Generator(seed: 1)
    /// let bits = rng.next()
    /// print(bits != 0)   // true
    /// ```
    ///
    /// - Returns: The next value in the SplitMix64 sequence, uniformly distributed over the full
    ///   `UInt64` range with a period of 2^64.
    public mutating func next() -> UInt64 {
        state = state &+ Self.increment
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
