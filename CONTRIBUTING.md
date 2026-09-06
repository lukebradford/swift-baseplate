# Contributing to Baseplate

Baseplate is designed to be contributed to **by AI agents** as much as by people. That means
the rules are explicit, the structure is repetitive on purpose, and every gate is machine-
checkable. If you are an agent, start with [`AGENTS.md`](AGENTS.md) — it has the commands and
the hard invariants. This document is the longer-form *how*.

Contributions of any size are welcome, but a good Baseplate PR is **small, single-purpose,
fully tested, and fully documented**. We would rather merge one polished utility than five
half-finished ones.

---

## What belongs in Baseplate

A utility belongs here if it is:

- **Broadly useful** — plausibly wanted by *at least three* small iOS apps, not one app's
  domain logic.
- **Boring and high-frequency** — the kind of chore every indie app re-implements (typed
  defaults, a review-prompt gate, a share sheet, a keychain read).
- **Not already owned** — we do **not** reinvent what Apple
  (`swift-collections` / `swift-algorithms` / `swift-async-algorithms`) or the Point-Free
  ecosystem (`swift-sharing`, `swift-dependencies`) already do well. When those cover it,
  Baseplate *complements* them, it does not compete. See the README's "What we deliberately
  don't build" section.
- **Dependency-free** — see invariant #1. If a feature genuinely needs a heavy dependency
  (RevenueCat, TelemetryDeck), it belongs in a *separate, optional* integration target, never
  in a core module. Propose it via an ADR first.

If you're unsure, open an issue with the "utility proposal" template before writing code.

---

## Adding a public symbol (the recipe)

1. **One file per type.** Create `Sources/<Module>/<Type>.swift`. Name the file exactly after
   the type. Delete the module's `_Placeholder.swift` if it's still there.
2. **Inject every side effect.** Anything non-deterministic — `Date`, `UUID`, a `Clock`,
   randomness, `UserDefaults`, `Bundle`, the current app version — is an initializer parameter
   with a live default:
   ```swift
   public init(
       defaults: UserDefaults = .standard,
       now: @escaping @Sendable () -> Date = { Date() }
   ) { … }
   ```
3. **Document it fully** using the template below. The example must compile.
4. **Test it deterministically.** Create `Tests/<Module>Tests/<Type>Tests.swift`. Cover the
   happy path *and* the edges (first launch, version rollback, corrupt data, clock moved
   backward, empty input). Inject fakes — never sleep, never hit the network or real disk.
5. **Update `CHANGELOG.md`** under `## [Unreleased]`.
6. **Run the gates** (see AGENTS.md): `swift test`, iOS `xcodebuild test` if iOS-only,
   `swift format lint --strict`, DocC build.

### Docstring template

Every public symbol uses this shape. Keep the example minimal but runnable.

```swift
/// One-sentence summary of what this does, in the imperative or declarative present.
///
/// A short paragraph on the *why* and any behavior a caller must know (thread-safety,
/// persistence, when it no-ops). State invariants explicitly.
///
/// ```swift
/// let gate = ReviewPromptGate(defaults: .standard)
/// gate.recordMeaningfulEvent()
/// if gate.shouldRequestReview(appVersion: "1.4.0") {
///     // present SKStoreReviewController
/// }
/// ```
///
/// - Parameters:
///   - appVersion: The current marketing version; a prompt fires at most once per version.
/// - Returns: `true` at most once per version, and only after enough meaningful events.
/// - Precondition: `minimumEvents >= 1`.
public func shouldRequestReview(appVersion: String) -> Bool
```

---

## Tests

- Framework: **swift-testing** (`import Testing`, `@Test`, `#expect`, `#require`) — bundled
  with the toolchain, no dependency.
- **Deterministic or it doesn't merge.** Inject a fixed `now`, a seeded RNG, an in-memory
  `UserDefaults(suiteName:)` you tear down, and a temp directory for file tests.
- For formatted output and (later) views, prefer **text/value snapshots**: assert against an
  exact expected string so a regression is a concrete, readable diff.
- Name tests by behavior: `@Test func fires_once_per_version()`, not `@Test func test1()`.

---

## Decisions (ADRs)

A choice that is hard to reverse, adds a dependency, changes the module graph, or breaks API
gets a short ADR in `docs/decisions/NNNN-title.md` (context → decision → consequences).
This mirrors the maintainer's house style: **predict before you act, and record it** — an
action with no record teaches the next agent nothing.

---

## Review

PRs are reviewed against the [Definition of Done](AGENTS.md#definition-of-done-a-change-is-not-done-until-all-of-these-hold)
and the hard invariants. An automated Claude reviewer (`.github/workflows/claude-review.yml`)
comments on each PR; a human owner (or a maintainer agent) gives the final approve/merge.
Be responsive to review comments and keep the branch rebased on `main`.

## Code of conduct

Be kind, be precise, assume good faith. Cite evidence over assertion. That's it.
