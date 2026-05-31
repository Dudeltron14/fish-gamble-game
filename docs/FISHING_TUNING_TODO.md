# Fishing Tuning Branch — Outstanding Items

Branch: `fishing-tuning`

---

- [ ] **Mechanic 11 — Bait rarity weights** — redesigned but not explicitly signed off after playtesting
- [x] ~~**Update FISHING.md**~~ — rewritten with all current values, fish catalogue, behavior docs, gear tables
- [x] ~~**Fish behavior documentation**~~ — 6-behavior system documented in FISHING.md
- [ ] **GearStatsPanel live refresh test** — verify panel updates correctly when bait/hook depletes mid-session and gear slots clear
- [ ] **2-player fishing sync** — verify reel, escape timer, and gear consumption work correctly with a second player connected
- [x] ~~**Escape timer feel**~~ — 3 seconds confirmed good
- [ ] **Bobber visual** — after casting, a bobber appears in the world at a distance proportional to cast quality. Perfect cast = max distance, bad cast = visibly shorter splash. Needs multiplayer sync so other players can see each other's bobbers.
- [x] ~~**Junk pool**~~ — Old Boot, Tin Can, Clump of Seaweed added (common rarity, 0 coins)
- [x] ~~**Chest (legendary)**~~ — Sunken Chest added (150c base, difficulty 2.2, 330c payout)
- [x] ~~**Key (legendary)**~~ — Ancient Key added (150c base, difficulty 2.5, 375c payout)
- [ ] **Fish sprites** — assign sprite frames from `assets/free fish/free fish.png` to each fish `.tres` file. Wire up catch result UI to display the fish sprite when a catch is made.

---

## Notes

- Junk, Chest, and Key use the existing FishData resource framework.
- Bobber will require a new scene + multiplayer sync.
- Merge into `master` when all items are checked off.
