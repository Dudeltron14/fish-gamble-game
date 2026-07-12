# Ship Checklist

This is the current launch gate. Completed launch-candidate work has been moved to `docs/RELEASE_NOTES.md` so this file stays focused on remaining decisions.

The intended ship path is the Web client at `https://fishgame.dudeltron14.win`, backed by the Linux Docker server. Windows Desktop export is out of scope unless desktop clients become a release target.

## Launch Status

- [x] Core Web-client/Linux-Docker closed-beta scope is implemented.
- [x] README, framework docs, fishing docs, architecture notes, screenshots, and release notes are aligned with the exported blackjack and final world pass.
- [x] Completed launch items have been moved into `docs/RELEASE_NOTES.md`.

## Pre-Launch Scope Decisions

These are not blockers for a trusted friends-and-family closed beta unless you want to harden the game before wider access.

- [x] Validate server-authoritative movement in live two-client playtest: local movement responsiveness, remote movement visibility, shop/casino hiding, fishing animation/bobber sync, and collision behavior.
- [ ] Shop UX playtest pass: gear modifiers available in shop, equipped items clearly marked, post-purchase equip reminders, auto-equip bait/hook when empty, and red warnings when bait runs out or tackle breaks.
- [ ] Fishing economy playtest pass: Glow Grub should prevent trash, trash should not be treated as a normal Common catch, and Pearl Clam frequency should be checked.
- [ ] Blackjack playtest pass: win/loss sounds, bet field lock during active hands, invalid high-bet/table-state bug, 6-deck shoe/shuffle/deck count, and bet reset behavior after all-in wins.
- [ ] Decide whether current fishing timing guardrails are sufficient, or promote stronger server-side reel validation into pre-launch scope.

## Post-Playtest

These are intentionally deferred until after the first closed beta playtest starts producing real economy feedback.

- [ ] Balance expanded 17-catch roster, payouts, bait pools, and Baby Kraken 2.5 difficulty from closed beta data.
- [ ] Design Ancient Key behavior beyond direct coin payout.
- [ ] Explore dead-broke recovery via shovel/worm-digging minigame.
- [ ] Explore momentum-based fishing.
- [ ] Consider new fish, rich-player skins, advanced upgrades, backpack/inventory slots, player trading, and multiplayer casino table spectators.
- [ ] Consider admin panel, day/night cycle, main-menu server query, and dock social cosmetics after closed beta priorities are stable.
