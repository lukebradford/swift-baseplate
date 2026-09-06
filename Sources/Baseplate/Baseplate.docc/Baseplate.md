# ``Baseplate``

The board every small iOS app builds on — a small, dependency-light Swift toolkit for indie iOS
apps built and maintained largely by AI agents.

## Overview

Baseplate is the pile of small, boring, high-frequency things every indie iOS app re-writes: a
keychain read, typed `UserDefaults`, a review-prompt gate that respects Apple's rules, a share
sheet, Dynamic-Type font scaling, a StoreKit entitlement cache, a cross-promotion shelf. It does
that work once — correctly, with complete docs and deterministic tests — so a person or an agent
can drop it in and move on.

Import the umbrella for everything, or a single module to keep the surface small:

```swift
import Baseplate         // everything
import BaseplateCore     // just the Foundation-only core
```

### Design principles

- **Dependency-free core.** `BaseplateCore` imports only Foundation and builds on macOS; the whole
  package adds zero third-party dependencies, so any app builds first-try.
- **Deterministic by construction.** Every side effect (`Date`, `UUID`, randomness, `UserDefaults`)
  is injected, so the entire test suite is reproducible.
- **Agent-native.** One public type per small file, a complete docstring with a compiled example on
  every symbol, and hard CI gates — so an agent can use it and contribute to it reliably.

## Topics

### Modules

- ``BaseplateCore``
- ``BaseplateUI``
- ``BaseplateLifecycle``
- ``BaseplateStoreKit``
