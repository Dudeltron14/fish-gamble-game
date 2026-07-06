# TODO

Living task list. The stricter release gate lives in `docs/SHIP_CHECKLIST.md`.

---

## Active Ship Work

- [ ] Validate blackjack card rendering in an exported build, including visual signoff on flip animation.
- [ ] Confirm Docker SQLite persistence through restart/update.
- [ ] Playtest expanded 17-catch roster, payouts, and Baby Kraken difficulty after the latest art/content pass.
- [ ] Verify new blackjack backdrop and flip animations in an exported Web build when playtesting is available.

---

## Phase 11 - Art / Manual

- [ ] Reposition zones to match final building positions.
- [ ] Confirm tilemap physics collision on water/buildings in a real play session.
- [ ] Final SpawnPoint pass.
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
- [x] Deployed clients default to `wss://fishserver.dudeltron14.win` with a custom server option.
- [x] Cloudflare Tunnel connectivity verified for the deployed game server.
- [x] Starter inventory and equipped gear are granted on registration and repaired for existing DB accounts.
- [x] Two-player movement, animation, fishing result sync, gear consumption, HUD refresh, and GearStatsPanel refresh verified.
- [x] Player-vs-player collision disabled so overlapping spawns do not launch players.
- [x] Bobber visual implemented, synced over multiplayer, hidden until cast completes, and scaled by cast quality.
- [x] Bobber splash animation plays when the bobber appears.
- [x] Catch sprites render as normalized world fade-outs using `FishData.icon` or `sprite_frame`.
- [x] Expanded catch roster to 17 entries: fish, junk, shells, crab, chest, and ancient key.
- [x] Generated fish/key sprites cleaned to transparent 64x64 assets and normalized in display.
- [x] Casino exterior replaced with style-matched transparent art.
- [x] Blackjack table backdrop added.
- [x] Blackjack horizontal card-flip animation implemented in code; visual signoff still pending.
- [x] Blackjack deal is blocked at 0 coins client-side and validated server-side.
- [x] Baby Kraken catch difficulty eased from 2.8 to 2.5.
- [x] Fish shop interior backdrop added behind the shop overlay.
- [x] `WaterTiles-6frames.png` is set up as animated water in the world TileSet.

---

## Backlog

- [ ] Inventory panel.
- [ ] Chat box.
- [ ] VFX on catch.
- [ ] Stronger anti-cheat: server-authoritative movement and server-validated fishing reel simulation.
- [ ] Optional Windows Desktop export preset, only if desktop clients become a release target.
