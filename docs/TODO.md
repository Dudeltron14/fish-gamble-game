# TODO

This file is for non-release backlog and saved implementation notes.

For ship status, use only `docs/SHIP_CHECKLIST.md`. Do not duplicate release checkboxes here.

---

## Saved Plans

### Blackjack Coin Burst VFX

Status: tracked in `docs/SHIP_CHECKLIST.md`.

- Trigger only from `src/scenes/casino/Blackjack.gd` in `_on_result()` when `outcome == "win"` and `payout > 0`.
- Do not trigger from `GameManager.coins_changed`; that would incorrectly fire on login, refunds, purchases, debug coin grants, or future coin changes.
- Runtime asset now lives at `assets/vfx/coin_burst_sheet.png`; it was copied out of the Super Pixel Effects pack so exports can omit the full pack.
- Asset metadata: 31 frames, one row, `64x64` per frame.
- Preferred implementation: add `src/scenes/vfx/CoinBurst.gd` and `src/scenes/vfx/CoinBurst.tscn`; animate a `Sprite2D` via `region_rect`, nearest filtering, then `queue_free()` at the end.
- Initial placement target: near the blackjack win/status text or between the win text and `coins_label`, so it reads as a casino payout celebration without covering the cards.
- Verification: blackjack win shows the burst, blackjack push/loss/bust/deal deduction do not; sprite remains crisp and cleans itself up.

---

## Backlog

These are not required for the current Web-client/Linux-Docker ship path unless promoted into `docs/SHIP_CHECKLIST.md`.

- Inventory panel.
- Chat box.
- VFX on catch.
- Post-playtest fish economy pass: tune 17-catch roster payouts, bait pools, Pearl Clam frequency, Glow Grub value, and Baby Kraken difficulty/reward after closed beta feedback.
- Stronger anti-cheat: server-validated fishing reel simulation beyond the current timing guardrails.
- Optional Windows Desktop export preset, only if desktop clients become a release target.
- Momentum-based fishing prototype where the player bar has weight/drift and counter-input applies momentum. GitHub issue #7.
- Dead-broke recovery: shovel/worm-digging minigame that avoids rocks and rewards worms. GitHub issue #8.
- Old-school pipe dock cosmetic/social interaction. GitHub issue #9.
- New fish expansion based on reward-tier, behavior, and theme gaps. GitHub issue #10.
- Ancient Key chest/case-opening reward flow beyond direct coin payout. GitHub issue #11.
- Rich-player skins from existing extra character sprite sheets and a possible hidden vendor. GitHub issue #12.
- Shotgun/shells special fishing upgrade that replaces rod/bait/tackle and targets uncommon fish. GitHub issue #13.
- Backpack/inventory slots for caught fish and player trading. GitHub issue #14.
- Multiplayer casino table spectator visuals. GitHub issue #15.
- Blackjack tracked 6-deck shoe plus shuffle animation/audio. GitHub issue #16.
- Admin panel for password resets, coin edits, item grants, database visibility, and admin promotion. GitHub issue #17.
- Day/night cycle with night-only fish per rarity tier. GitHub issue #18.
- Main-menu server query for online status, player count, and ping. GitHub issue #19.
