# 0001 — First tagged release: 0.1.0

- **Status:** Accepted
- **Date:** 2026-09-10
- **Decider:** Luke Bradford (owner), executed by a local Claude Code maintainer session on his
  explicit instruction.

## Context

The v1 API surface was complete and `main` was green, but Baseplate had never been *released* as a
consumable version. Two problems blocked a clean first tag:

1. **A stale test-count claim.** `CHANGELOG.md` advertised "350+ deterministic tests." The real
   suite is **178** tests (178 `@Test` functions across 21 files / 25 suites; 0 parameterized, 0
   XCTest — verified four independent ways). "350+" was an aspirational number from the v1 draft and
   roughly 2× the truth — exactly the kind of claim that misleads in a public tagged release.
2. **A prematurely-created tag.** An annotated `0.1.0` tag already existed locally (unpushed),
   pointing at `be2c791` — a commit whose `CHANGELOG.md` still said "350+" and still filed everything
   under `[Unreleased]` with no `[0.1.0]` section. Pushing it as-is would have shipped the stale,
   wrong changelog as the release of record.

Per `AGENTS.md` invariant #8 and `CLAUDE.md`, cutting/pushing a release tag is owner-executed and not
something an agent does unilaterally. The owner directed this release in-session.

## Decision

Cut **0.1.0** as the first tagged release, from a commit whose CHANGELOG is accurate:

1. Corrected the CHANGELOG in one commit (`35946a7`): promoted `[Unreleased]` → `[0.1.0] -
   2026-09-10`, opened a fresh `[Unreleased]`, added Keep-a-Changelog compare/release links, and
   fixed the test count **350+ → 178**.
2. **Verified before tagging** with a four-dimension release-readiness audit (each finding
   adversarially re-checked): the test count is exactly 178; every public symbol named in the
   changelog exists in `Sources/`; the four modules + umbrella match `Package.swift`'s five products;
   the core is dependency-free; README/`llms.txt` claims (Swift 6.2, iOS 17+, macOS 14+, `from:
   "0.1.0"`, badges) are accurate; and no file still contains "350".
3. Confirmed **all four CI jobs green on the release commit** `35946a7` — macOS, **iOS Simulator
   (full surface)**, swift-format lint, and DocC — before creating the tag.
4. **Moved the tag onto the verified commit:** deleted the stale local `0.1.0` (it had never been
   pushed, so this was invisible externally) and re-created it as an annotated tag on `35946a7`,
   confirming `git show 0.1.0:CHANGELOG.md` reflects the fix, then pushed `main` and the tag.

## Consequences

- `github.com/lukebradford/swift-baseplate@0.1.0` is now resolvable by SPM; the README's `from:
  "0.1.0"` install snippet works.
- The released CHANGELOG is truthful about the suite size (178), removing a ~2× overstatement.
- **Tag hygiene lesson for future releases:** never create the release tag before the release commit
  exists and is CI-green. A tag pins a *tree*, so committing "on top" does not update an
  already-created tag — it must be moved. Moving a tag is safe only while it is unpushed; once pushed,
  a tag is immutable in practice (consumers and SPM caches may have it).
- A GitHub *Release* (release notes on the Releases page) was **not** created — the owner's
  instruction was "tag and push." That remains an optional follow-up the owner can take.
- SemVer/pre-1.0 policy is unchanged: breaking changes still go through an `@available` deprecation
  cycle and land in `CHANGELOG.md`.
