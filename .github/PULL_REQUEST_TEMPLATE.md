<!-- Thanks for contributing to Baseplate! Keep PRs small and single-purpose. -->

## What & why

<!-- One paragraph: what this changes and why it belongs in Baseplate (which apps/needs). -->

## Module(s) touched

<!-- e.g. BaseplateCore -->

## Definition of Done

- [ ] New/changed public symbols have a complete DocC docstring **with a compiling example**
- [ ] Deterministic tests cover happy path **and** edges (all side effects injected — no wall
      clock, network, real filesystem, or unseeded randomness)
- [ ] `swift test` green; iOS `xcodebuild test` green if the code is iOS-only
- [ ] `swift format lint --strict` clean; DocC builds clean
- [ ] `CHANGELOG.md` updated under `## [Unreleased]`
- [ ] No new dependency, no new cross-module edge; hard invariants (AGENTS.md) hold
- [ ] Any module `_Placeholder.swift` removed once real symbols exist

## Notes for the reviewer

<!-- Anything non-obvious: tradeoffs, an ADR link, follow-ups intentionally left out. -->
