// swift-tools-version: 6.2
import PackageDescription

// Baseplate — a small, cohesive, dependency-light Swift toolkit for indie iOS apps
// built and maintained largely by AI agents. See AGENTS.md for the operating manual.
//
// Design rules encoded here (do not violate without an ADR — see CONTRIBUTING.md):
//   • The core has ZERO third-party dependencies so any app builds first-try.
//   • Every target compiles in Swift 6 language mode with strict concurrency.
//   • Platform-specific code is gated with #if canImport(...) so the portable
//     surface still builds on macOS CI (fast, simulator-free feedback for agents).
//   • Test targets use swift-testing (bundled with the toolchain) — no test deps either.

let strict: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
]

let package = Package(
    name: "Baseplate",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // Umbrella: `import Baseplate` re-exports every module.
        .library(name: "Baseplate", targets: ["Baseplate"]),
        // Curated individual modules for minimal import surface.
        .library(name: "BaseplateCore", targets: ["BaseplateCore"]),
        .library(name: "BaseplateUI", targets: ["BaseplateUI"]),
        .library(name: "BaseplateLifecycle", targets: ["BaseplateLifecycle"]),
        .library(name: "BaseplateStoreKit", targets: ["BaseplateStoreKit"]),
    ],
    targets: [
        // MARK: Umbrella
        .target(
            name: "Baseplate",
            dependencies: ["BaseplateCore", "BaseplateUI", "BaseplateLifecycle", "BaseplateStoreKit"],
            swiftSettings: strict
        ),

        // MARK: Examples — compiled in CI so the usage snippets can never rot (invariant #5).
        .executableTarget(
            name: "Examples",
            dependencies: ["Baseplate"],
            path: "Examples/Sources/Examples",
            swiftSettings: strict
        ),

        // MARK: Core — Foundation (+ gated Security for Keychain), no UIKit/SwiftUI. Portable.
        .target(
            name: "BaseplateCore",
            swiftSettings: strict
        ),
        .testTarget(
            name: "BaseplateCoreTests",
            dependencies: ["BaseplateCore"],
            swiftSettings: strict
        ),

        // MARK: UI — SwiftUI ergonomics + design-system primitives (UIKit bits gated).
        .target(
            name: "BaseplateUI",
            dependencies: ["BaseplateCore"],
            swiftSettings: strict
        ),
        .testTarget(
            name: "BaseplateUITests",
            dependencies: ["BaseplateUI"],
            swiftSettings: strict
        ),

        // MARK: Lifecycle — indie app-lifecycle business logic (review/what's-new/feedback/cross-promo).
        .target(
            name: "BaseplateLifecycle",
            dependencies: ["BaseplateCore"],
            swiftSettings: strict
        ),
        .testTarget(
            name: "BaseplateLifecycleTests",
            dependencies: ["BaseplateLifecycle"],
            swiftSettings: strict
        ),

        // MARK: StoreKit — testable StoreKit 2 entitlement/observer for the no-backend indie.
        .target(
            name: "BaseplateStoreKit",
            dependencies: ["BaseplateCore"],
            swiftSettings: strict
        ),
        .testTarget(
            name: "BaseplateStoreKitTests",
            dependencies: ["BaseplateStoreKit"],
            exclude: ["Fixtures/Products.storekit"],  // an Xcode/StoreKit-integration fixture, not a runtime resource
            swiftSettings: strict
        ),
    ]
)
