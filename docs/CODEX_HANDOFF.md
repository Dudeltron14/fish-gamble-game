# Codex Handoff

Last updated: 2026-07-06

## 2026-07-06 Current Status Addendum

The sections below preserve the original handoff context from the earlier checklist push. The live source of truth is now `docs/SHIP_CHECKLIST.md`.

Since the original handoff, these items have been completed and verified in playtest:

- Deployed clients default to `wss://fishserver.dudeltron14.win`, with a custom server option.
- Cloudflare Tunnel is the active WSS route to the Docker game server.
- Registration/login works against the Docker server.
- Starter inventory and equipped gear are granted on registration and repaired for existing database accounts.
- Gear consumption works across bait, hook durability, break/re-equip, HUD refresh, and GearStatsPanel refresh.
- Two-player movement, animations, fishing result sync, and player collision behavior have been playtested.
- Bobber visual, cast-distance scaling, multiplayer sync, and bobber spawn splash are implemented.
- Catch sprites now render as normalized world fade-outs using `FishData.icon` first and `sprite_frame` fallback.
- The catch roster has expanded to 17 entries, including fish, junk, crab/shells/snail, Sunken Chest, and Ancient Key.
- Casino exterior art, blackjack backdrop, blackjack card flip animation, and zero-coin deal validation have been added.
- Baby Kraken difficulty was eased from `2.8` to `2.5`.
- Fish shop interior backdrop is wired behind the shop overlay.
- Distinct gear icons are assigned for rods, bait, and hooks and displayed in shop rows.
- `WaterTiles-6frames.png` is configured as animated water in the world TileSet.
- Animated water has been extended to cover a 1080p viewport around spawn.

Still open at this point:

- Validate blackjack cards/backdrop/flip animation in an exported Web build.
- Confirm Docker SQLite persistence through restart/update.
- Playtest the expanded 17-catch roster, payouts, and Baby Kraken 2.5 difficulty.
- Finish final world-art tasks: zone placement, tile/building/water collision pass, and spawn pass.
- Capture README screenshots.
- Confirm GHCR package visibility and run/confirm Linux server + Web exports from CI or local Godot.
- Windows Desktop export is out of scope for this ship path unless desktop clients become a release target.

## Current Operating Context

Work in:

```text
C:\Users\Noah\Documents\fish-game
```

Active branch:

```text
master
```

Use the stricter shipping bar from `docs/SHIP_CHECKLIST.md` as the source of truth. Do not downgrade the goal to the softer Claude memory framing. The current intent is to ship a friends-scale multiplayer Godot fishing/casino game, but still address the important validation, persistence, deployment, playtest, and polish items before release.

## Current Prompt / Direction

The user explicitly wants the original code-review checklist addressed:

1. Fix authoritative validation: server-side zone validation and fishing result validation or anti-cheat constraints.
2. Add `wss://...` connection support for deployed web clients.
3. Fix fishing failure RPC arity.
4. Persist equipped rod/bait/hook and hook durability.
5. Playtest and sign off bait rarity/no-bait junk economy.
6. Verify 2-player fishing sync, gear consumption, HUD and GearStatsPanel live refresh.
7. Implement bobber visual with multiplayer sync.
8. Render caught fish/key/chest/junk sprites in result UI using `sprite_frame`.
9. Finish world art tasks: reposition zones, tilemap collision, final spawn/zone pass.
10. Keep Windows Desktop export out of scope unless desktop clients become a release target.
11. Validate blackjack card rendering in an exported build.
12. Confirm GHCR image visibility, deployed WSS routing, and Docker persistence.
13. Update stale docs so `TODO.md`, `FRAMEWORKS.md`, `README.md`, and `FISHING.md` agree.

When playtesting, ask the user one checklist/tuning question at a time and wait for feedback.

## Changes Made In This Session

Code changes:

- `src/autoloads/NetworkManager.gd`
  - Added `connect_to_url(url)` for full `ws://` and `wss://` endpoints.
  - `connect_to_server(host, port)` now delegates to `connect_to_url`.
- `src/scenes/ui/LoginScreen.gd`
  - Server field now accepts either `host[:port]` or a full URL such as `wss://example.com/ws`.
- `src/scenes/world/World.gd`
  - Added `get_zone_for_peer(peer_id)` and rectangle-shape zone hit testing on the server world scene.
- `src/autoloads/NetAPI.gd`
  - Server refreshes peer zone from the world before gated actions: zone change, fishing start, shop buy, blackjack bet.
  - Added `equipment_loaded` signal and `notify_equipment_loaded(...)` RPC.
- `src/server/FishingServer.gd`
  - Fixed `notify_fishing_start` failure calls to include the required `line_strength` argument.
  - Clamps client cast quality to `0.0..1.0`.
  - Captures bait/rod/hook stats before consuming gear, so the last bait still affects the bite that consumes it.
  - Adds pending fish metadata and basic timing guardrails against instant success RPCs.
  - Persists equipment changes after bait depletion/hook durability changes.
  - Worm tuning now bypasses normal rarity bonuses and picks starter catches directly.
- `src/server/AuthServer.gd`
  - Adds/migrates player columns: `equipped_rod_id`, `equipped_bait_id`, `equipped_tackle_id`, `hook_durability`.
  - Starter items now seed equipped gear and hook durability.
  - Login reloads equipped gear, validates owned state, restores hook durability, persists fallback state, and sends equipment to the client.
- `src/server/ShopServer.gd`
  - Equipping gear persists immediately.
  - Hook equip sends correct current/max durability.
- `src/resources/baits/worm.tres`
  - Worm is now starter-level bait:
    - `rarity_weights = {"common": 0.85, "uncommon": 0.15, "rare": 0.00, "legendary": 0.00}`
    - Description updated.

Docs changes:

- Added `docs/SHIP_CHECKLIST.md`.
- Rewrote `docs/TODO.md` around the stricter ship list.
- Updated `docs/FRAMEWORKS.md` bait weights and summary.
- Updated `docs/FISHING.md` for Worm's new intended behavior.
- Added `docs/SHIP_CHECKLIST.md` to the README documentation index.
- Added distinct generated gear icons and Godot import sidecars for rods, bait, and hooks.
- Added fish shop interior art and casino/backdrop art updates.
- Extended animated water coverage to 1080p around spawn.
- Marked Windows Desktop export out of scope for the Web-client/Linux-Docker ship path.

## Current Playtest Feedback

No bait:

- User says no-bait fishing feels good as-is.
- It should stay punishing.
- Purpose: teaches players the game, pushes them to buy Worms, and punishes players who gamble everything away.

Worm:

- User said Worm felt too strong.
- Direction: nerf it to basic-level fish and rare junk only.
- Implemented current Worm behavior:
  - 8% junk
  - 70% common starter fish
  - 22% uncommon starter fish
  - No normal Rare/Legendary pool from Worm.
- Important caveat: the global 1% Sunken Chest pre-roll still happens before bait selection. Ask the user later whether Worm/no-bait should be excluded from the global chest roll.

Shiny Lure:

- User direction: Rare fish should appear inconsistently.
- Implemented current Shiny Lure behavior:
  - 5% junk
  - 45% common starter fish
  - 35% uncommon starter fish
  - 14% Rare
  - 1% Legendary

Magic Bait:

- User said Legendary seemed high.
- User accepted the lower Legendary profile and requested a 2.5% Common chance.
- Implemented current Magic Bait weights:
  - 2.5% Common
  - 42.5% Uncommon
  - 40% Rare
  - 15% Legendary

## Previous Exact Next Question

Historical note only; this bait retest has since been completed.

```text
Previous item: bait retest.

After the bait changes, please retest Worm, Shiny Lure, and Magic Bait. Do the new rarity mixes feel right enough to sign off, or does one still need adjustment?
```

## Validation Run

Before Worm tuning:

- `git diff --check` passed.
- Godot MCP project state reported:
  - Godot `4.6.3`
  - `compile_error_count: 0`
  - `error_count: 0`
  - `warning_count: 0`
- Detailed Godot diagnostics showed repeated MCP addon Roslyn loader messages from `godot_dotnet_mcp`, but no fish-game script compile/runtime errors.

After Worm tuning:

- `git diff --check` passed.
- Godot runtime/project validation has not yet been rerun after the Worm-specific code change.

## Previous Remaining Ship Items

Historical note only. For the current state, use `docs/SHIP_CHECKLIST.md`.

- Playtest/sign off bait economy:
  - No bait: accepted.
  - Worm: changed, needs retest.
  - Shiny Lure: changed, needs retest.
  - Magic Bait: changed, needs retest.
- Finish art/manual world tasks: zones, collision confirmation, spawn pass.
- Windows Desktop export remains optional/out of scope unless explicitly revived.
- Validate blackjack card rendering in exported build.
- Confirm GHCR visibility and Docker persistence.
- Rerun Godot validation after current changes.

## Notes For The Next Agent

- Keep edits scoped and data-driven where possible.
- The user is actively playtesting and wants one question at a time.
- Do not revert any current worktree changes.
- Use `rg` for search and `apply_patch` for manual edits when possible.
- Be careful with Godot warnings-as-errors:
  - Avoid `:=` from Variant-returning expressions.
  - Use explicit types for dictionary/array lookups and `pop_back()`.
- This repo has some older markdown files with encoding artifacts; small patches are safer than broad encoded-line matches.
