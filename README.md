<div align="center">

# Baseplate

**The board every small iOS app builds on.**

A small, cohesive, dependency-light Swift toolkit for indie iOS apps — built to be used *and
maintained* largely by AI coding agents.

[![CI](https://github.com/lukebradford/swift-baseplate/actions/workflows/ci.yml/badge.svg)](https://github.com/lukebradford/swift-baseplate/actions/workflows/ci.yml)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2017%2B%20%7C%20macOS%2014%2B-blue.svg)](https://developer.apple.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

Baseplate is the pile of small, boring, high-frequency things every indie iOS app re-writes:
a keychain read, typed `UserDefaults`, a review-prompt gate that respects Apple's rules, a
share sheet, Dynamic-Type font scaling, a StoreKit entitlement cache, a "More apps by me"
shelf. None of it is hard. All of it is fiddly, easy to get subtly wrong, and pure friction to
re-derive in every project.

Baseplate does that work once, correctly, with **complete docs and deterministic tests**, so a
person or an agent can drop it in and move on.

## Why "for agents"?

The differentiator isn't the features — it's that the whole library is shaped so an AI agent
can *use it and contribute to it reliably*:

- **Every public symbol has a DocC docstring with a runnable, CI-compiled example.** Agents
  synthesize call sites from docstrings; a copy-pasteable example beats a wiki.
- **Every side effect is injected** (`Date`, `UUID`, clock, randomness, `UserDefaults`), so the
  entire test suite is deterministic and an agent can trust a green run.
- **One public type per small file**, named exactly after the type — minimal context to load,
  minimal blast radius to edit.
- **A zero-dependency core** that builds first-try, and **hard CI gates** (Swift 6 build +
  tests + format + DocC) that give an agent an unambiguous merge signal.
- **An [`AGENTS.md`](AGENTS.md)** with exact commands, the module map, and the invariants.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) if you (or your agent) want to add a utility.

## Installation

Swift Package Manager:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/lukebradford/swift-baseplate.git", from: "0.1.0")
]
```

Then depend on just what you need (recommended) or the umbrella:

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "BaseplateCore", package: "swift-baseplate"),
    .product(name: "BaseplateUI", package: "swift-baseplate"),
    // …or simply .product(name: "Baseplate", …) for everything.
])
```

Requires Swift 6.2 / Xcode 26, targeting iOS 17+ (the core also builds on macOS 14+).

## The modules

Import only what you use — each module is small and independent, and the core has no
dependencies at all.

### `BaseplateCore` — Foundation only, portable

```swift
import BaseplateCore

// Type-safe keychain, survives reinstall, no dependency.
let deviceID = KeychainItem<String>(service: "com.you.app", account: "deviceID")
try deviceID.set(UUID().uuidString)

// Versioned, self-expiring, clock-skew-guarded Codable persistence.
let store = CodableDefaultsStore<Draft>(key: "draft", schemaVersion: 2, maxAge: 60*60*24*30)
store.save(draft)

// Reproducible randomness for daily challenges & stable previews.
var rng = SeededRandomNumberGenerator(seed: DailySeed().seed)
let pick = colors.randomElement(using: &rng)

// Correct, localized humanization.
Humanize.relativeDate(postedAt, relativeTo: .now)   // "3 hours ago"
```

### `BaseplateUI` — SwiftUI ergonomics & design-system primitives

```swift
import BaseplateUI

Text("Score").scaledFont(size: 28, weight: .bold, relativeTo: .title)  // fixed size + Dynamic Type
Color(hex: "#1E90FF")                                                  // hex init
Color.adaptive(light: .white, dark: .black)                           // light/dark in one call
someView.exportedAsImage(scale: 3)                                    // SwiftUI view → UIImage
```

### `BaseplateLifecycle` — the indie app-lifecycle chores

```swift
import BaseplateLifecycle

// Ask for a review the right way: only at a delight moment, once per version, respecting limits.
reviewGate.recordMeaningfulEvent()
if reviewGate.shouldRequestReview(appVersion: appVersion) { requestReview() }

// One shared portfolio list drives every app's cross-promo shelf (define PortfolioApp once).
CrossPromoShelf(apps: portfolio.excludingApp(withID: myAppStoreID)) { app in open(app) }
```

### `BaseplateStoreKit` — StoreKit 2 for the no-backend indie

```swift
import BaseplateStoreKit

let entitlements = EntitlementStore(productIDs: ["com.you.app.pro"])
await entitlements.start()                     // observes Transaction.updates, caches last-known-good
if entitlements.isEntitled("com.you.app.pro") { unlockPro() }
```

> Every snippet above is compiled in CI (see [`Examples/`](Examples/Sources/Examples)), so it can't
> drift from the real API. Signatures may still be refined before 1.0; the DocC docs are the source
> of truth once published.

## What we deliberately don't build

Baseplate stays small by leaning on the best-in-class packages instead of duplicating them:

| Need | Use instead |
|---|---|
| Data structures / algorithms | `apple/swift-collections`, `swift-algorithms`, `swift-async-algorithms` |
| Shared/persisted app state, DI | `pointfreeco/swift-sharing`, `pointfreeco/swift-dependencies` |
| Full IAP / paywall backend | `RevenueCat` (Baseplate only covers the no-backend StoreKit 2 case) |
| Remote image loading | `kean/Nuke` |
| Heavy networking | `Alamofire` / `kean/Get` |
| Fancy SwiftUI effects | `EmergeTools/Pow` |

Optional adapter targets that bridge Baseplate to `swift-dependencies` and `swift-sharing`
are on the roadmap; the core will always stay dependency-free.

## Status

Pre-1.0 and evolving. Semantic versioning; breaking changes go through an `@available`
deprecation cycle and land in [`CHANGELOG.md`](CHANGELOG.md).

## License

[MIT](LICENSE) © Luke Bradford
