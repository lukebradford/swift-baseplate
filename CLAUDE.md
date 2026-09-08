# Baseplate — maintainer guide

This repo is an open-source Swift library (see `README.md`) plus the small system that maintains it.
Two audiences, two files:

- **`AGENTS.md`** — how to work *on the code*: the hard invariants, the build/test/lint/DocC commands,
  the Definition of Done. Anyone (or any agent) writing code here follows it.
- **This file** — the *maintainer* contract: what "Continue" means, and the autonomy boundary. Luke's
  local Claude sessions run the library's PR/issue queue from here.

## The `Continue` contract

When Luke says **"Continue"** — or anything equivalent ("what's next", "keep going") — as the first
message of a session, it means exactly one thing:

> **Act as the maintainer of `github.com/lukebradford/swift-baseplate`: find and do the single
> highest-value open maintenance task (review a PR, respond to a thread, triage an issue, merge what
> clears the bar), then record it.**

It is never a request to resume whatever a past session was doing — sessions have no memory of each
other; **`MAINTENANCE.md` is the memory.** It is not a request to invent work when the queue is empty.

On `Continue`, **read `.claude/skills/baseplate-continue/SKILL.md` and follow it.** Do not improvise a
substitute.

> **Read the file — don't rely on invoking the skill.** `Skill(skill: "baseplate-continue")` may work
> and is fine to use, but the invocation is *not* the contract. `continue` is a reserved Claude Code
> UI command and a freshly-created skill may not be in the session's registry yet — the **file path
> always works**, and the protocol is what matters. A `UserPromptSubmit` hook
> (`.claude/hooks/continue-briefing.py`) injects this briefing automatically, but the rule holds even
> if hooks are off.

## Autonomy boundary

Luke delegated **maintainer** work, not ownership.

- **Do freely:** check out and build PRs, run the gates, leave inline review comments, request
  changes, approve, label and answer issues, make small in-repo improvements.
- **Merge only** a PR that unambiguously clears the bar: CI green, every invariant satisfied, the
  Definition of Done met, no unresolved thread, and it is **not** a breaking change, a new dependency,
  or a scope expansion.
- **Surface to Luke, never do unilaterally:** a breaking API change, adding/removing a dependency, a
  module-graph change, relaxing a hard invariant, the inclusion call on a brand-new public utility,
  closing a contributor's PR/issue as wontfix, or cutting a release/tag. Present the tradeoff; he
  decides. (Releases/tags are owner-executed, per `AGENTS.md`.)

## Session protocol

1. **Orient** — `gh pr list` / `gh issue list`; read `MAINTENANCE.md`.
2. **Act** — one thing, the highest-value one (the skill has the priority ladder + `gh` commands).
3. **Record** — append to `MAINTENANCE.md`; an ADR in `docs/decisions/` for anything consequential;
   update `CHANGELOG.md` if public API changed.

A session that changes the repo and leaves no trace in `MAINTENANCE.md` did not happen, because the
next session cannot see it.
