# Ship Checklist

This is the current launch gate. Completed launch-candidate work has been moved to `docs/RELEASE_NOTES.md` so this file stays focused on remaining decisions.

The intended ship path is the Web client at `https://fishgame.dudeltron14.win`, backed by the Linux Docker server. Windows Desktop export is out of scope unless desktop clients become a release target.

## Launch Status

- [x] Core Web-client/Linux-Docker closed-beta scope is implemented.
- [x] README, framework docs, fishing docs, architecture notes, screenshots, and release notes are aligned with the exported blackjack and final world pass.
- [x] Completed launch items have been moved into `docs/RELEASE_NOTES.md`.

## Pre-Launch Scope Decisions

These are not blockers for a trusted friends-and-family closed beta unless you want to harden the game before wider access.

- [ ] Validate server-authoritative movement in live two-client playtest: local movement responsiveness, remote movement visibility, shop/casino hiding, fishing animation/bobber sync, and collision behavior.
- [ ] Decide whether current fishing timing guardrails are sufficient, or promote stronger server-side reel validation into pre-launch scope.

## Post-Playtest

These are intentionally deferred until after the first closed beta playtest starts producing real economy feedback.

- [ ] Balance expanded 17-catch roster, payouts, bait pools, and Baby Kraken 2.5 difficulty from closed beta data.
