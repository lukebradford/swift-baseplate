# Maintenance log

The running memory of Baseplate maintainer ("Continue") sessions. Sessions don't remember each other;
this file is how each one knows what the last one did. Newest entry first. Keep entries terse: what was
looked at, what was done, and the single next thing to check.

See `CLAUDE.md` for the Continue contract and `.claude/skills/baseplate-continue/SKILL.md` for the routine.

---

## 2026-09-10 — Cut 0.1.0 (first tagged release)

- **State:** v1 surface complete, `main` green, no open PRs/issues. Owner directed a real first
  release in-session (this is an owner-authorized override of the "tags are owner-executed" boundary
  in `CLAUDE.md` / `AGENTS.md` #8).
- **Did:** corrected `CHANGELOG.md` (commit `35946a7`) — promoted `[Unreleased]` → `[0.1.0] -
  2026-09-10`, fresh `[Unreleased]`, compare links, and **fixed the test-count claim 350+ → 178**
  (real count: 178 `@Test`, 0 parameterized, 0 XCTest). Ran a 4-dimension release-readiness audit
  (all content clean; every claimed symbol exists, modules match `Package.swift`, deps still zero).
  Pushed `main`; waited for **all 4 CI jobs green on `35946a7`** (incl. iOS Simulator). The stale,
  never-pushed `0.1.0` tag pointed at the pre-fix commit `be2c791`, so **deleted and re-created it**
  as an annotated tag on `35946a7`, verified `git show 0.1.0:CHANGELOG.md` shows 178, and pushed the
  tag. ADR: `docs/decisions/0001-first-tagged-release-0.1.0.md`. Then, on owner instruction,
  **published a formal GitHub Release** for `0.1.0` (title "0.1.0 — first tagged release"; notes
  drawn from the `[0.1.0]` CHANGELOG section + install/requirements/status; not a draft, not a
  prerelease) — <https://github.com/lukebradford/swift-baseplate/releases/tag/0.1.0>.
- **Next session should check:** `gh pr list` / `gh issue list` as usual — 0.1.0 is fully shipped
  (tag + Release). Tag-hygiene note for future releases: a tag pins a tree — never create a release
  tag before the release commit is CI-green; moving a tag is only safe while unpushed.

---

## 2026-09-08 — Protocol set up

- **State:** repo published and public (`main`), CI green (build/test/lint/DocC), v1 surface complete.
  No open PRs, no open issues yet.
- **Did:** installed the Continue maintainer protocol — `CLAUDE.md` contract, the
  `baseplate-continue` skill, the `UserPromptSubmit` hook, and this log. Removed the API-key GitHub
  Action reviewer (`.github/workflows/claude-review.yml`) in favor of this local, no-per-PR-cost flow.
- **Next session should check:** `gh pr list` / `gh issue list`. If both are empty, the highest-value
  move is advancing the library itself (a ≥3-app utility the audit flagged but v1 deferred, or wiring
  a first consumer app — "goal #2"). Otherwise, work the queue per the skill.
