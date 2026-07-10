# TODO

This file is for non-release backlog and saved implementation notes.

For ship status, use only `docs/SHIP_CHECKLIST.md`. Do not duplicate release checkboxes here.

---

## Saved Plans

### Blackjack Coin Burst VFX

Status: tracked in `docs/SHIP_CHECKLIST.md`.

- Trigger only from `src/scenes/casino/Blackjack.gd` in `_on_result()` when `outcome == "win"` and `payout > 0`.
- Do not trigger from `GameManager.coins_changed`; that would incorrectly fire on login, refunds, purchases, debug coin grants, or future coin changes.
- Use `assets/Super Pixel Effects Gigapack (Free Version)/spritesheet/Magic Bursts/directional_coin_burst_001/directional_coin_burst_001_small_yellow/spritesheet.png`.
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
- Stronger anti-cheat: server-authoritative movement and server-validated fishing reel simulation.
- Optional Windows Desktop export preset, only if desktop clients become a release target.
