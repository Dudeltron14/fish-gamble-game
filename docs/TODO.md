# TODO

Living task list. The stricter release gate lives in `docs/SHIP_CHECKLIST.md`.

---

## Active Ship Work

- [ ] Playtest bait rarity/no-bait junk economy and sign off weights.
- [ ] Verify 2-player fishing sync, gear consumption, HUD refresh, and GearStatsPanel refresh.
- [ ] Implement bobber visual with multiplayer sync.
- [ ] Render caught fish/key/chest/junk sprites in result UI using `FishData.sprite_frame`.
- [ ] Validate blackjack card rendering in an exported build.
- [ ] Confirm deployed Web client can connect through `wss://.../ws`.
- [ ] Confirm Docker SQLite persistence through restart/update.

---

## Phase 11 - Art / Manual

- [ ] Reposition zones to match final building positions.
- [ ] Assign item icons on `.tres` resources if item display surfaces use them.
- [ ] Set up `WaterTiles-6frames.png` as animated water in the TileSet.
- [ ] Confirm tilemap physics collision on water/buildings in a real play session.
- [ ] Final SpawnPoint pass.
- [ ] Add Windows Desktop export preset if local desktop builds are part of ship.
- [ ] Capture gameplay screenshots for README.

---

## Done / Current Baseline

- [x] Project skeleton + autoloads.
- [x] WebSocket networking.
- [x] Auth + SQLite.
- [x] World + Player + multiplayer spawn.
- [x] Fishing system and tuning branch mechanics.
- [x] Shop system and equip flow.
- [x] Blackjack.
- [x] HUD, GearStatsPanel, volume sliders.
- [x] Docker + CI/CD baseline.
- [x] Data-driven `.tres` item framework.
- [x] Player animations: idle, walk_right, fishing, hook.
- [x] Host & Play local testing flow.
- [x] Linux dedicated server + Web export presets.
- [x] Music playlists and SFX wiring.
- [x] Bait uses-per-stack purchasing and per-bite decrement.
- [x] Rod line_strength affects reel fill and escape timer refill.
- [x] Equipped gear and hook durability persist in SQLite.
- [x] Full URL client connection support for `ws://` and `wss://` endpoints.
- [x] Basic server-side zone refresh before gated actions.
- [x] Basic fishing result timing guardrails.

---

## Backlog

- [ ] Inventory panel.
- [ ] Chat box.
- [ ] VFX on catch.
- [ ] Stronger anti-cheat: server-authoritative movement and server-validated fishing reel simulation.
