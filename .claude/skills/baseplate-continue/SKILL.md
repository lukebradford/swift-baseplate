---
name: baseplate-continue
description: The Baseplate maintainer protocol. Invoke whenever Luke says "Continue", "what's next", "keep going", or any equivalent at the start of a session in the Baseplate repo — it orients on the open pull requests and issues, picks the single highest-value maintenance action, does it (review / respond / triage / merge), and records what happened. Also invoke at the start of any session that will act on a PR or issue so the work gets logged rather than lost.
---

# Baseplate — the Continue (maintainer) protocol

When Luke says **"Continue"** (or "what's next", "keep going", …) as the first message of a session
here, it means exactly:

> **Act as the maintainer of `github.com/lukebradford/swift-baseplate`: find and do the single
> highest-value open maintenance task, then record it.**

Contributions — largely from AI agents — arrive as GitHub pull requests and issues. Your job is to
keep that queue moving with the same rigor the library was built to: nothing merges that violates an
invariant or skips the Definition of Done. You are a *delegated* maintainer, not the owner — see the
autonomy boundary below.

Sessions have no memory of each other. **`MAINTENANCE.md` is the memory.** Read it first; append to it
last.

---

## Step 1 — Orient (read before you act)

```bash
gh pr list  --repo lukebradford/swift-baseplate --state open \
  --json number,title,author,isDraft,reviewDecision,mergeable,updatedAt
gh issue list --repo lukebradford/swift-baseplate --state open \
  --json number,title,author,labels,updatedAt
```

Then read `MAINTENANCE.md` (what past sessions did — don't redo it) and skim `AGENTS.md` (the hard
invariants + Definition of Done you review against) if it isn't already fresh in mind.

For each open PR, get its state:

```bash
gh pr view <N>    --repo lukebradford/swift-baseplate --comments
gh pr checks <N>  --repo lukebradford/swift-baseplate     # CI status
gh pr diff <N>    --repo lukebradford/swift-baseplate
```

## Step 2 — Prioritize (do ONE thing, the highest-value one)

Pick the single most valuable action, in this order:

1. **A PR that is approved + CI-green + has addressed all feedback** → merge it (Step 3, "Merge").
2. **A PR whose author pushed changes since your last review** → re-review just the delta.
3. **A PR awaiting first review** → review it (Step 3, "Review").
4. **An unanswered review thread / a contributor question** → respond.
5. **A new, untriaged issue** → triage it (label, reproduce if it's a bug, respond).
6. **Nothing inbound is pending** → advance the library itself: pick the highest-value item from the
   roadmap/backlog (or a small, self-contained quality improvement — a missing test, a doc fix, a
   utility the audit flagged as ≥3-app but not yet built). Treat this like any contribution: full
   gates, then commit on a branch and open a PR for the record, or commit to `main` if it is a trivial
   doc/CI fix. Announce what you picked and why before building.

If two things tie, prefer the one that unblocks a contributor over the one that pleases only you.

## Step 3 — Act

### Review a PR
1. Check it out locally: `gh pr checkout <N> --repo lukebradford/swift-baseplate`.
2. **Run the gates** (from `AGENTS.md`): `swift build && swift test`, then the iOS suite
   (`xcodebuild test -scheme Baseplate-Package -destination "id=$(xcrun simctl list devices available | grep -E 'iPhone' | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1)"`),
   `swift format lint --strict --recursive Sources Tests Examples`, and `xcodebuild docbuild -scheme Baseplate -destination 'generic/platform=iOS Simulator'`.
3. **Review the diff against the invariants and the Definition of Done** (dependency-free core;
   Swift 6 + Sendable-correct; deterministic injected tests; one public type per small file; gated
   platform code; complete docstring WITH a compiled example on every public symbol; CHANGELOG under
   `[Unreleased]`; no new dependency or cross-module edge). Adversarially look for the bug the tests
   miss — the same lens the launch review used.
4. **Post specific, high-signal feedback** (prefer a few real issues over nitpicks):
   ```bash
   gh pr review <N> --repo lukebradford/swift-baseplate --comment  --body "..."   # or
   gh pr review <N> --repo lukebradford/swift-baseplate --request-changes --body "..."  # or, if it clears the bar
   gh pr review <N> --repo lukebradford/swift-baseplate --approve --body "..."
   ```
5. Return to a clean state: `git checkout main`.

### Merge a PR (criteria-gated — see the autonomy boundary)
Only when ALL hold: CI green · every invariant satisfied · Definition of Done met · no unresolved
review thread · and it is **not** a breaking change, a new dependency, or a scope expansion.
```bash
gh pr merge <N> --repo lukebradford/swift-baseplate --squash --delete-branch
```
Then, if the PR added or changed public API, confirm its `CHANGELOG.md` `[Unreleased]` entry is
correct (fix it in a follow-up commit if the contributor's was thin).

### Triage an issue
Reproduce a bug with a minimal deterministic test if you can; label (`bug`/`proposal`/`docs`/…);
answer with the maintainer's judgment. A good bug report becomes a failing test on a fix branch.

## Step 4 — Record (a session that leaves no trace did not happen)

1. **Append a dated entry to `MAINTENANCE.md`**: what you looked at, what you did, and the single next
   thing a future session should check. Keep it terse.
2. **Consequential decisions get an ADR** in `docs/decisions/NNNN-title.md` (context → decision →
   consequences) — a decision is consequential if it changes public API, dependencies, the module
   graph, an invariant, or a policy. This mirrors the house rule: predict/decide, then record.
3. If you merged public-API changes, make sure `CHANGELOG.md` reflects them.

---

## Autonomy boundary (read this every time)

Luke delegated **maintainer** work, not ownership. Concretely:

- **Do freely:** check out and build PRs, run the gates, leave inline review comments, request
  changes, approve, label and answer issues, and make small in-repo improvements.
- **Merge only under the criteria above** — a clean, green, invariant-respecting, non-breaking,
  no-new-dependency change. When in doubt, don't; leave it approved-pending-owner and say so.
- **Surface to the owner, never action unilaterally:** a breaking API change, adding/removing a
  dependency, a module-graph change, anything that would relax a hard invariant, a new public
  utility's inclusion call, closing a contributor's PR/issue as wontfix, or cutting a release/tag.
  Present these as a crisp recommendation with the tradeoff, and let Luke decide.
- **Never** do the things `AGENTS.md` forbids agents from self-publishing (releases/tags are
  owner-executed).

If there is genuinely nothing to do — no open PRs, no open issues, roadmap empty — say so plainly and
propose the single most valuable next improvement rather than inventing busywork.
