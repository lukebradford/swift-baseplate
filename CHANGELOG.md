# Changelog

All notable changes to Baseplate are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-09-10

### Added

Initial v1 surface — a Swift 6.2 package (`Baseplate` umbrella + four modules), 178 deterministic
tests, complete DocC docstrings with compiled examples, and agent-native repo conventions.

**BaseplateCore** (Foundation only, portable)
- `KeychainItem<Value>` — dependency-free generic-password Keychain store (String/Data/Codable),
  with `KeychainAccessibility` and a typed `KeychainError`.
- `CodableDefaultsStore<Value>` — versioned, max-age-expiring, clock-skew-guarded Codable persistence.
- `UserDefault<Value>` — typed defaults property wrapper with a fallback for unknown enum values.
- `SeededRandomNumberGenerator` (resumable xorshift64) and `SplitMix64Generator`.
- `DailySeed` — stable per-UTC-day seed + once-per-day gate.
- `Humanize` — locale-safe relative dates, byte counts, durations, ordinals.
- `NameOrdering` — Finder-style numeric-aware name ordering.
- `Collection.subscript(safe:)`.

**BaseplateUI** (SwiftUI; UIKit gated)
- `View.scaledFont(size:weight:design:relativeTo:)` — fixed sizes that honor Dynamic Type.
- `Color(hex:)`, `Color.adaptive(light:dark:)` (+ `UIColor`), and `ColorComponents` (Codable).
- `Haptics` + `HapticsPreference` — pre-primed feedback with a user toggle.
- `ShareSheet` + `ShareableImage`, and `View.exportedAsImage(scale:)`.
- `Binding.isPresent()`, `View.errorAlert(_:)`, `View.if(_:transform:)`.

**BaseplateLifecycle**
- `ReviewPromptGate` — value-gated, once-per-version App Store review logic.
- `FirstLaunch`, `VersionChange`, `ShowOnceFlag`, `WhatsNewGate` — launch/version primitives.
- `DiagnosticsReport` + `MailComposeView` — pre-filled feedback email with diagnostics.
- `PortfolioApp`, `AppStoreCampaignLink`, `CrossPromoShelf` — cross-promotion with attribution.

**BaseplateStoreKit**
- `EntitlementEngine` + `TransactionFact` + `EntitlementState` — pure, testable entitlement logic.
- `Grandfather` — grant a feature by original purchased version.
- `EntitlementStore` — live StoreKit 2 observer with last-known-good caching and restore.

**Repository**
- Agent-native conventions: `AGENTS.md`, `CONTRIBUTING.md` + docstring template, deterministic-test
  policy, one-symbol-per-file, compiled `Examples/`, CI gates (build + test + swift-format + DocC),
  an automated Claude PR reviewer, and `Tools/preflight.sh` (App Store submission checks).

<!--
Keep entries under these headings while unreleased, newest first:
### Added / ### Changed / ### Deprecated / ### Removed / ### Fixed / ### Security
On release, rename [Unreleased] to the version + date and start a fresh [Unreleased] block.
-->

[Unreleased]: https://github.com/lukebradford/swift-baseplate/compare/0.1.0...HEAD
[0.1.0]: https://github.com/lukebradford/swift-baseplate/releases/tag/0.1.0
