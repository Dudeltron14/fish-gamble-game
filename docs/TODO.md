# TODO

Living task list. Move items to DONE when complete.

---

## Phase 11 — Art / Manual (user)

- [ ] **Paint TileMap** — open `World.tscn` → `TileMapLayer`, create TileSet from `assets/ForgottenMemories/TileSet.png`, paint map
- [ ] **Reposition zones** — drag `DockZone`, `ShopZone`, `CasinoZone` in `World.tscn` to match painted map
- [ ] **Move SpawnPoint** — drag `Marker2D` to town center on painted map
- [ ] **Item icons** — set `icon: Texture2D` on each `.tres` in `src/resources/` using icon sheets from `assets/`
- [ ] **Water animation** — set up `WaterTiles-6frames.png` as an AnimatedTile in the TileSet

---

## Nice to have

- [ ] **Inventory panel** — dedicated UI to view owned items (currently only accessible via shop Equip button)
- [ ] **Chat box** — HUD chat for connected players
- [ ] **VFX on catch** — wire Super Pixel Effects frames to `FishingMinigame._show_result` for a coin burst
- [ ] **Audio** — wire `AudioManager.play_sfx()` calls to catch, purchase, blackjack win events
- [ ] **Rod line_strength** — currently stored but not wired to fish escape chance
- [ ] **Bait uses_per_stack** — currently display only; decrement on use and enforce in FishingServer
- [ ] **Nginx TLS** — run `certbot --nginx -d yourdomain.com` on VPS before first player session
- [ ] **GitHub Packages visibility** — set `ghcr.io/dudeltron14/fish-gamble-game` to public so Docker pull works without auth

---

## Done

- [x] Project skeleton + autoloads (Phase 1)
- [x] WebSocket networking (Phase 2)
- [x] Auth + SQLite (Phase 3)
- [x] World + Player + multiplayer spawn (Phase 4)
- [x] Fishing system (Phase 5)
- [x] Shop system (Phase 6)
- [x] Blackjack (Phase 7)
- [x] HUD + polish (Phase 8)
- [x] Docker + CI/CD (Phase 9)
- [x] All framework wiring + equip system (Phase 10)
