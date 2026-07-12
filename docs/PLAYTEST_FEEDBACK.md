# Playtest Feedback

Use this file as the shared intake and triage guide for closed beta feedback. Each actionable feedback item should become its own branch and pull request so contributors can see what is actively being fixed.

## How Playtesters Should Report

Ask playtesters to include this information:

```text
Title:
Severity: Blocker / Bug / Polish / Balance / Idea
Build or date tested:
Platform: Web browser + OS, or Godot client
Account name:
Area: Login / World / Fishing / Shop / Blackjack / Audio / Performance

Steps to reproduce:
Expected result:
Actual result:
How often it happens:
Screenshot, clip, or logs:
Extra notes:
```

Good feedback is specific. "Fishing feels weird" is useful as a first impression, but "after the bobber splashes, the reaction prompt disappears before I can press E in Chrome on Windows" is actionable.

## Triage Flow

1. Confirm whether the report is reproducible.
2. Decide whether it is pre-launch, post-playtest, or not planned.
3. Create one branch for the item.
4. Open one pull request for the fix.
5. Link the feedback report in the PR description.
6. Move any launch-blocking item into `docs/SHIP_CHECKLIST.md`.

Suggested labels:

```text
playtest
bug
blocker
polish
balance
casino
fishing
shop
networking
web
audio
docs
```

## Current Policy

- Closed beta blockers belong in `docs/SHIP_CHECKLIST.md`.
- Economy balance belongs in post-playtest unless it blocks basic progression.
- Stronger fishing anti-cheat is deferred unless playtest feedback shows active abuse or obvious breakage.
- Each feedback fix should stay in a dedicated PR, even if several bugs are discovered during the same session.

