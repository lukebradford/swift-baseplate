import Testing

@testable import BaseplateCore

@Suite struct SplitMix64GeneratorTests {

    @Test func same_seed_produces_same_sequence() {
        var a = SplitMix64Generator(seed: 0xDEAD_BEEF)
        var b = SplitMix64Generator(seed: 0xDEAD_BEEF)
        let first = (0..<10).map { _ in a.next() }
        let second = (0..<10).map { _ in b.next() }
        #expect(first == second)
    }

    @Test func zero_seed_is_valid_and_produces_nonzero_output() {
        var rng = SplitMix64Generator(seed: 0)
        #expect(rng.state == 0)  // no remap, unlike xorshift
        #expect(rng.next() != 0)
    }

    @Test func scrambles_adjacent_seeds_apart() {
        var a = SplitMix64Generator(seed: 0)
        var b = SplitMix64Generator(seed: 1)
        // A single call must diffuse a one-bit input difference across the output.
        #expect(a.next() != b.next())
    }

    @Test func state_restore_resumes_the_sequence_exactly() {
        var rng = SplitMix64Generator(seed: 42)
        _ = rng.next()
        let saved = rng.state
        let continuation = (0..<5).map { _ in rng.next() }

        var resumed = SplitMix64Generator(state: saved)
        let resumedValues = (0..<5).map { _ in resumed.next() }

        #expect(continuation == resumedValues)
    }
}
