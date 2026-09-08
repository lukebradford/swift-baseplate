# Maintenance log

The running memory of Baseplate maintainer ("Continue") sessions. Sessions don't remember each other;
this file is how each one knows what the last one did. Newest entry first. Keep entries terse: what was
looked at, what was done, and the single next thing to check.

See `CLAUDE.md` for the Continue contract and `.claude/skills/baseplate-continue/SKILL.md` for the routine.

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
