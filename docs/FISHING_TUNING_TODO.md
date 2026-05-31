# Fishing Tuning Branch — Outstanding Items

Branch: `fishing-tuning`

---

- [ ] **Mechanic 11 — Bait rarity weights** — redesigned but not explicitly signed off after playtesting
- [ ] **Update FISHING.md** — values changed significantly during tuning (fish speeds, escape timer, drain rate, bait weights, payout formula, fish behaviors) — doc is stale
- [ ] **Fish behavior documentation** — 6-behavior action system (slowdown, hover, burst, shimmy, freezedash, flip/continue) not documented anywhere yet
- [ ] **GearStatsPanel live refresh test** — verify panel updates correctly when bait/hook depletes mid-session and gear slots clear
- [ ] **2-player fishing sync** — verify reel, escape timer, and gear consumption work correctly with a second player connected
- [x] ~~**Escape timer feel** — 3 seconds confirmed good~~
- [ ] **Bobber visual** — after casting, a bobber appears in the world at a distance proportional to cast quality. Perfect cast = max distance, bad cast = visibly shorter splash. Needs multiplayer sync so other players can see each other's bobbers floating in the water while waiting for a bite.
- [ ] **Junk pool** — add common-rarity junk items (e.g. Old Boot, Tin Can, Soggy Hat) to the catchable item pool. Junk should have very low or 0 coin value and appear frequently when fishing without bait/gear. Discourages bare fishing and makes bait feel essential.
- [ ] **Chest (legendary)** — add a Chest as a legendary-rarity catchable. Should have high coin value or potentially contain items. Lives in the fish resource pool as a FishData.
- [ ] **Key (legendary)** — add a Key as a legendary-rarity catchable alongside the Chest. Future use: keys could unlock chests for bonus loot. For now, treat as a high-value coin reward.

- [ ] **Fish sprites** — assign sprite frames from `assets/free fish/free fish.png` to each fish `.tres` file via `sprite_frame` field. Also wire up the catch result UI to display the fish sprite when a player lands a catch, so players see what they caught rather than just a text name.

---

## Notes

- Junk, Chest, and Key use the existing FishData resource framework — just drop `.tres` files in `src/resources/fish/`. No code changes needed.
- Bobber will require a new scene + multiplayer sync via MultiplayerSynchronizer or RPC.
- Merge into `master` when all items are checked off.
