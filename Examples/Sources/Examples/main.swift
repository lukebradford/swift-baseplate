// Examples — a compile-checked tour of Baseplate's public API.
//
// Every call in this target is built in CI (see AGENTS.md invariant #5), so the snippets shown
// in the README and DocC can never drift from the real API. This is not meant to be run as a
// useful program; it exists so the compiler keeps the docs honest.

import Foundation

print("Baseplate examples — see the per-module files in this target for real usage.")

coreExamples()
lifecycleExamples()
storeKitExamples()

#if canImport(UIKit)
_ = uiExamplesAreCompiled  // reference the gated examples so they're type-checked on iOS
#endif
