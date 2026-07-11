# Release Notes

## Launch Candidate Scope

Target: browser-based closed beta at `https://fishgame.dudeltron14.win`, backed by the Linux Docker server and Cloudflare Tunnel route at `wss://fishserver.dudeltron14.win`.

Desktop Windows export is out of scope for this launch path.

## Completed For Closed Beta

### Networking / Deployment

- Web clients connect over `wss://fishserver.dudeltron14.win`.
- Docker server deployment is running from GHCR.
- GHCR package visibility has been confirmed.
- Cloudflare Tunnel origin routing has been confirmed.
- SQLite persistence survives container restart/update.
- Linux server export and Web export have been run from CI or local Godot.

### Account / Persistence

- Registration/login works against the deployed Docker server.
- Starter inventory is granted on registration and repaired for existing accounts.
- Equipped rod, bait, hook, and hook durability persist across login.
- Password reset can be run as a server command without wiping inventory or balance.

### Fishing

- Server validates player zone before fishing starts.
- Fishing result RPC has basic timing guardrails against instant success.
- Bait and hook durability are consumed server-side.
- Gear consumption, hook break/re-equip, HUD refresh, and GearStatsPanel refresh have been verified in two-player sessions.
- Bobber visuals are multiplayer-synced.
- Bobber splash animation is implemented.
- Catch result sprites are normalized and shown as world fade-outs.
- No-bait, Worm, Glow Grub, and Magic Bait behavior is ready for closed beta; detailed fish economy balance is deferred to post-playtest.

### Casino / Blackjack

- Blackjack runs through a server-side state machine.
- Server validates table zone and balance before betting.
- Zero-coin deal prevention is implemented.
- Card rendering, card flip animation, deck-to-slot dealing animation, backdrop, and coin-burst win VFX have been validated in exported/Web playtest.
- Leaving an active blackjack hand warns that the current bet will be forfeited.

### World / UI / Art

- Casino exterior, casino backdrop, and fish shop interior art are wired.
- Player position is server-simulated from client movement input; final live two-client validation is tracked in `docs/SHIP_CHECKLIST.md`.
- Water animation setup and 1080p world coverage have been verified.
- Tilemap/building/water collision has been checked in a real play session.
- Spawn point behavior has been confirmed.
- UI theme uses warm-toned flat assets without the animated corner-bracket hover override.
- Current README screenshots are added in `docs/screenshots/`.

## Deferred Until After Closed Beta Feedback

- Economy tuning for the expanded 17-catch roster, payouts, bait pools, and Baby Kraken difficulty/reward.
- Stronger fishing/reel anti-cheat beyond the current timing guardrails.
