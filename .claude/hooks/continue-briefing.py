#!/usr/bin/env python3
"""UserPromptSubmit hook: a bare "Continue" that OPENS a session in the Baseplate repo means
"act as the maintainer — find and do the single highest-value open maintenance task".

Mid-conversation, "continue" keeps its ordinary meaning (resume the current task), so this fires
only when the prompt is the session's first user turn. Anything unexpected — bad JSON, an unreadable
transcript — exits silently rather than blocking the prompt.
"""

import json
import os
import sys

# Prompts that mean "brief me as the maintainer". Compared after lowercasing + stripping punctuation.
TRIGGERS = {"continue", "keep going", "what's next", "whats next", "next", "what should i do"}

BRIEFING = """The user's entire first message this session was a bare "Continue" (or equivalent).

In the Baseplate repository that is DEFINED to mean exactly:

    "Act as the maintainer: find and do the single highest-value open maintenance task."

Baseplate (github.com/lukebradford/swift-baseplate) is an open-source Swift library whose
contributions arrive as GitHub pull requests and issues, largely from AI agents. On Continue you keep
that queue moving: review PRs, respond to review threads, triage issues, and merge what clearly meets
the bar. Do NOT ask the user to clarify, and do NOT resume unrelated work from a previous session.

DO THIS:

  1. Read `.claude/skills/baseplate-continue/SKILL.md` and follow it exactly — it has the
     orient -> prioritize -> act -> record routine and the precise `gh` commands. (Invoking the
     `baseplate-continue` skill is fine if it works, but the FILE is the reliable entry point.)

  2. Read `MAINTENANCE.md` — the running log of past Continue sessions. Sessions have no memory of
     each other; that file is the memory. Orient with `gh pr list` and `gh issue list`.

  3. Review code against `AGENTS.md` (the hard invariants + Definition of Done) and `CONTRIBUTING.md`.

AUTONOMY BOUNDARY: you may review, comment inline, label, and approve freely. You may MERGE a PR only
when it UNAMBIGUOUSLY clears the bar (CI green + every invariant + the Definition of Done) AND it is
not a breaking change, a new dependency, or a scope expansion. Anything consequential or ambiguous — a
breaking API change, a new dependency, a design shift, or closing someone's PR/issue as wontfix — is
surfaced to the owner (Luke) as a recommendation, never actioned unilaterally.

Guard: if this conversation visibly already contains an in-progress task, ignore this note and treat
"Continue" with its ordinary meaning."""


def is_user_turn(entry):
    """True for a real typed user message. Tool results also arrive as type=="user"; they are not."""
    if entry.get("type") != "user" or entry.get("isMeta"):
        return False
    content = (entry.get("message") or {}).get("content")
    if isinstance(content, str):
        return bool(content.strip())
    if isinstance(content, list):
        return any(isinstance(b, dict) and b.get("type") == "text" for b in content)
    return False


def user_turns_in(path):
    """Count real user turns already in the transcript. 0 or 1 means this prompt is the first."""
    if not path or not os.path.exists(path):
        return 0
    count = 0
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    if is_user_turn(json.loads(line)):
                        count += 1
                except json.JSONDecodeError:
                    continue
    except OSError:
        return 0
    return count


def main():
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    prompt = (payload.get("prompt") or "").strip().lower().rstrip(".!?…")
    if prompt not in TRIGGERS:
        return 0

    # The current prompt may or may not be appended to the transcript before this hook runs,
    # so <=1 is "this is the session's first user turn".
    if user_turns_in(payload.get("transcript_path")) > 1:
        return 0

    json.dump(
        {
            "systemMessage": '"Continue" -> act as Baseplate maintainer: triage & act on the highest-value open PR/issue (see .claude/skills/baseplate-continue/SKILL.md).',
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": BRIEFING,
            },
        },
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
