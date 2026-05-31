# Fishing Tuning Branch — Outstanding Items

Branch: `fishing-tuning`

---

- [ ] **Mechanic 11 — Bait rarity weights** — needs playtesting sign-off (each bait type, no-bait junk feel)
- [x] ~~**Update FISHING.md**~~ — rewritten with all current values, fish catalogue, behavior docs
- [x] ~~**Fish behavior documentation**~~ — 6-behavior system documented in FISHING.md
- [ ] **GearStatsPanel live refresh test** — fish until bait/hook depletes, verify HUD + Tab panel update live
- [ ] **2-player fishing sync** — verify reel, escape timer, and gear consumption work with second player
- [x] ~~**Escape timer feel**~~ — 3 seconds confirmed good
- [ ] **Bobber visual** — bobber appears at cast distance proportional to cast quality; needs multiplayer sync
- [x] ~~**Junk pool**~~ — Old Boot, Tin Can, Clump of Seaweed (common, 0 coins, skip minigame)
- [x] ~~**Chest (legendary)**~~ — Sunken Chest: 1% fixed rate regardless of gear, skips minigame, 330c
- [x] ~~**Key (legendary)**~~ — Ancient Key: normal legendary pool, skips minigame, 375c
- [ ] **Fish sprites** — assign frames from `assets/free fish/free fish.png`; wire sprite display in catch result UI

---

## Recently completed (this session)

- Music playlist system — world/fishing/shop share one playlist; casino has its own
- SFX system — 17 sound effects wired across all game systems
- GearStatsPanel — top-right corner, collapses to title, Tab to expand, Music/SFX volume sliders
- Volume sliders persist via `user://settings.cfg`
- Bait rarity complete redesign — no-bait = 95% common/junk; progression to Magic Bait
- Blackjack forfeit on leave — no more stuck sessions
- Junk/Chest/Key catchables — all skip the fishing minigame

## Notes

- Bobber requires new scene + multiplayer sync.
- Fish sprites: `sprite_frame` field already on all FishData .tres files, user sets which frame.
- Merge into `master` when all items checked off.
