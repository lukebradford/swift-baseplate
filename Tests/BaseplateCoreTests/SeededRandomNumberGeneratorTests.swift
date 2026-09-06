import Testing

@testable import BaseplateCore

@Suite struct SeededRandomNumberGeneratorTests {

    @Test func same_seed_produces_same_sequence() {
        var a = SeededRandomNumberGenerator(seed: 12345)
        var b = SeededRandomNumberGenerator(seed: 12345)
        let first = (0..<10).map { _ in a.next() }
        let second = (0..<10).map { _ in b.next() }
        #expect(first == second)
    }

    @Test func different_seeds_diverge() {
        var a = SeededRandomNumberGenerator(seed: 1)
        var b = SeededRandomNumberGenerator(seed: 2)
        #expect(a.next() != b.next())
    }

    @Test func zero_seed_is_remapped_to_nonzero_and_never_stuck() {
        var rng = SeededRandomNumberGenerator(seed: 0)
        #expect(rng.state != 0)
        // xorshift on a nonzero state never produces zero.
        for _ in 0..<1000 {
            #expect(rng.next() != 0)
        }
    }

    @Test func zero_seed_matches_documented_fallback_constant() {
        var fromZero = SeededRandomNumberGenerator(seed: 0)
        var fromConstant = SeededRandomNumberGenerator(seed: 0x9E37_79B9_7F4A_7C15)
        #expect(fromZero.next() == fromConstant.next())
    }

    @Test func state_restore_resumes_the_sequence_exactly() {
        var rng = SeededRandomNumberGenerator(seed: 777)
        _ = rng.next()
        _ = rng.next()
        let saved = rng.state

        // Continue the original.
        let continuation = (0..<5).map { _ in rng.next() }

        // A generator restored from the saved state must reproduce the continuation.
        var resumed = SeededRandomNumberGenerator(state: saved)
        let resumedValues = (0..<5).map { _ in resumed.next() }

        #expect(continuation == resumedValues)
    }

    @Test func zero_state_restore_is_remapped() {
        let rng = SeededRandomNumberGenerator(state: 0)
        #expect(rng.state != 0)
    }
}
