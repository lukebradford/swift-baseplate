# AGENTS.md — operating manual for Baseplate

This file is the contract for any agent (Claude Code, Codex, Cursor, Gemini, Amp, …)
working in this repository. It is intentionally terse and command-first. Human-facing
prose lives in [`README.md`](README.md); the how-to-contribute walkthrough lives in
[`CONTRIBUTING.md`](CONTRIBUTING.md). **Read the nearest `AGENTS.md`** — larger modules
may nest their own.

> Baseplate is a small, dependency-light Swift toolkit for indie iOS apps that are built
> and maintained largely by AI agents. Its value is not novel functionality — it is a
> **uniform, deterministic-in-tests, agent-swappable** contract over the boring, high-
> frequency iOS chores that every small app re-implements.

---

## Commands (copy-paste; these are the source of truth)

```bash
# Fast, portable feedback — Core + all platform-independent logic. No simulator. Use this first.
swift build
swift test

# Full build/test INCLUDING iOS-only (UIKit / StoreKit-runtime) code.
# Build needs no device; test needs a concrete simulator (resolve a UDID robustly):
xcodebuild build -scheme Baseplate -destination 'generic/platform=iOS Simulator'
UDID=$(xcrun simctl list devices available | grep -E 'iPhone' \
       | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1)
xcodebuild test -scheme Baseplate-Package -destination "id=$UDID" -skipPackagePluginValidation
# (Tests live in the `Baseplate-Package` scheme. If a name is in doubt: `xcodebuild -list`.)

# Format — Apple swift-format, bundled with the Swift 6 toolchain. CI fails on lint diffs.
swift format lint --strict --recursive Sources Tests
swift format --in-place --recursive Sources Tests     # auto-fix

# Docs — DocC must build clean (CI gate). Uses Xcode's built-in DocC (no package plugin,
# so the dependency-free invariant stays intact).
xcodebuild docbuild -scheme Baseplate -destination 'generic/platform=iOS Simulator'

# Release preflight — run against a CONSUMING app's built .app before submitting to the App Store.
Tools/preflight.sh /path/to/YourApp.app
```

Every PR must leave `swift test`, the iOS `xcodebuild test`, `swift format lint --strict`,
and the DocC build all green. Green-or-block: that is your merge signal.

---

## Module map

| Module | Imports | May depend on | What lives here |
|---|---|---|---|
| `BaseplateCore` | Foundation (+ Security, gated) | *(nothing)* | Keychain, typed defaults, seeded RNG, humanization formatters, name ordering. Portable; builds on macOS. |
| `BaseplateUI` | SwiftUI (+ UIKit, gated) | `BaseplateCore` | Dynamic-Type font scaling, share sheet + view→image export, color (hex/adaptive/Codable), haptics, curated SwiftUI ergonomics. |
| `BaseplateLifecycle` | Foundation, SwiftUI, MessageUI (gated) | `BaseplateCore` | Review-prompt gate, what's-new / first-launch / version gates, feedback composer, cross-promotion shelf + portfolio registry. |
| `BaseplateStoreKit` | StoreKit | `BaseplateCore` | Testable StoreKit 2 entitlement store + transaction observer + restore + grandfathering, for the no-backend indie. |
| `Baseplate` | *(umbrella)* | all of the above | `import Baseplate` re-exports every module. |

Dependency edges point **downward only** (`Core` never imports anything else in the repo).
Adding a new upward or sideways edge requires an ADR (see CONTRIBUTING.md § Decisions).

---

## HARD INVARIANTS — never violate

1. **The core is dependency-free.** No target may add a third-party package dependency
   without an ADR. `BaseplateCore` imports only Foundation plus, where unavoidable, a
   platform-gated Apple system framework (currently `Security`, behind `#if canImport(Security)`,
   for the Keychain) — never a third-party package. A consumer must be able to add Baseplate and
   build first-try with zero transitive surprises. Test targets use the toolchain's built-in
   `swift-testing` — no test dependencies either.
2. **Swift 6, strict concurrency, Sendable-correct.** Every target builds in Swift 6
   language mode. Public API is `Sendable`-correct. `@unchecked Sendable` is allowed only in
   a tiny, audited, commented primitive with a one-line justification. Prefer explicit
   `@MainActor` on UI-touching types over ambient assumptions.
3. **Determinism is mandatory in tests.** No test may touch the wall clock, the network, the
   real filesystem outside a temp dir, or unseeded randomness. Every side-effecting input
   (`Date`, `UUID`, `Clock`, random, `UserDefaults`, `Bundle`) is **injected** via an
   initializer parameter with a live default (e.g. `init(now: @escaping () -> Date = { Date() })`).
   This is the single biggest lever for agents being able to run and trust the suite.
4. **One public symbol per file; small files.** A file is named exactly after the type it
   defines and contains that type (plus its tightly-coupled private helpers). Aim < ~200
   lines. This minimizes the context an edit must load and its blast radius.
5. **Every public symbol has a complete DocC docstring with a runnable example.** `///`
   summary, `- Parameters`, `- Returns`, `- Throws`, and documented `Precondition`/
   `Invariant` where they exist, plus a fenced ` ```swift ` example. Examples must compile
   (they are mirrored into `Examples/` or DocC and built in CI).
6. **Platform-specific code is gated.** Wrap UIKit/MessageUI/etc. in
   `#if canImport(UIKit)` so the portable surface keeps building on macOS CI.
7. **No breaking change without a deprecation cycle.** Removing or renaming public API goes
   through `@available(*, deprecated, message: "...")` first, and lands in `CHANGELOG.md`.
   The committed API baseline (`Tools/api-baseline/`) makes any accidental break a reviewable
   diff.
8. **Outward-facing actions are draft-only.** Publishing a release, pushing tags, editing the
   GitHub repo settings, or anything users see externally is prepared as a copy-paste-ready
   artifact + numbered steps for the human owner. Agents do not self-publish.

---

## Definition of Done (a change is not done until all of these hold)

- [ ] New/changed public symbols have complete DocC docstrings **with a compiling example**.
- [ ] Deterministic tests cover the happy path **and** the failure/edge paths; all injected.
- [ ] `swift test` green; `xcodebuild test` (iOS Simulator) green if the code is iOS-only.
- [ ] `swift format lint --strict` clean; DocC builds clean.
- [ ] `CHANGELOG.md` updated under `## [Unreleased]` (Added/Changed/Fixed/Deprecated).
- [ ] No new dependency; no new cross-module edge; invariants above hold.
- [ ] The `_Placeholder.swift` for a module is deleted once that module has real symbols.

---

## PR conventions

- Branch: `feat/<module>-<symbol>`, `fix/<module>-<what>`, `docs/…`, `chore/…`.
- One logical change per PR. Keep diffs reviewable.
- Commit subject: `<module>: imperative summary` (≤ 72 chars), e.g. `Core: add KeychainItem<Value>`.
- Fill in `.github/PULL_REQUEST_TEMPLATE.md`. The maintainer is a locally-run Claude Code session
  (the "Continue" protocol in `CLAUDE.md`) that reviews against the Definition of Done and the
  invariants; the owner makes the final call on anything consequential.

## Where things go

```
Sources/<Module>/<Type>.swift        one public type per file
Tests/<Module>Tests/<Type>Tests.swift
Examples/Sources/Examples/           compile-checked usage snippets
Tools/preflight.sh                   App Store rejection preflight (for consuming apps)
docs/llms.txt                        machine-readable index of the public API for agents
```
