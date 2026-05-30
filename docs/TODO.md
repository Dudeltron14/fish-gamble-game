# TODO

Living task list. Move items to DONE when complete.

---

## Phase 11 — Art / Manual (user)

- [~] **Paint TileMap** — In progress. Island with dock complete. Casino + shop sprites placed.
- [ ] **Reposition zones** — Match zone boxes to final building positions after all sprites placed
- [ ] **Move SpawnPoint** — Already done (user confirmed correct)
- [ ] **Item icons** — set `icon: Texture2D` on each `.tres` in `src/resources/` using icon sheets from `assets/`
- [ ] **Water animation** — set up `WaterTiles-6frames.png` as an AnimatedTile in the TileSet
- [ ] **Windows export preset** — add Windows Desktop preset in Project → Export for local testing
- [ ] **Tilemap physics collision** — Paint physics shapes on water tiles in TileSet editor so player can't walk into water

---

## Active bugs

- [ ] **Playing card sprites not rendering** — Blackjack shows empty card areas instead of images. Fix: right-click `assets/Playing Cards/` in FileSystem dock → Reimport. If still broken after reimport, path or import issue.
- [ ] **Second client multiplayer** — Use Debug → Run Multiple Instances (not two editors). Register account first, then Login.

---

## Nice to have (backlog)

- [ ] **Inventory panel** — dedicated UI to view owned items (currently only accessible via Shop Equip button)
- [ ] **Chat box** — HUD chat for connected players
- [ ] **VFX on catch** — wire Super Pixel Effects frames to fishing catch moment
- [ ] **Audio** — wire `AudioManager.play_sfx()` calls to catch, purchase, blackjack win
- [ ] **Casting distance wired** — power bar currently cosmetic; wire to wait time (full cast = shorter wait)
- [ ] **Rod line_strength** — stored but not wired to fish escape chance
- [ ] **Bait uses_per_stack** — display only; should decrement on use in FishingServer
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
- [x] Player animations: idle, walk_right (flip_h for left), fishing, hook
- [x] Playing card sprites wired (loads from assets/Playing Cards/)
- [x] All assets imported to fish-game/assets/
- [x] Host & Play button for single-instance local testing
- [x] export_presets.cfg: Linux (dedicated server) + Web presets
- [x] Camera2D following local player (2.5x zoom, smooth)
- [x] WASD + arrow keys movement
- [x] E key to interact / open overlays
- [x] Fishing minigame difficulty tuned (fish speed fix, harder reel)
- [x] Fishing controls text corrected (E to cast/react, A/D to reel)
- [x] Shop display fix (theme_override_constants, free() instead of queue_free())
- [x] Host & Play RPC routing fixed (call_local + _peer_id() fallback)
- [x] Blackjack type inference errors fixed
- [x] Casino sprite placed in world
- [x] Shop sprite updated in world
- [x] Player size correct (CollisionShape2D scaled, AnimatedSprite2D scale reset)
