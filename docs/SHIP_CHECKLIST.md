# Ship Checklist

This is the single source of truth for ship status. Other docs may describe systems, saved plans, or historical handoff context, but release checkboxes should live here only.

The checklist intentionally uses the stricter review criteria: server-authoritative where it affects coins, deployable over WSS, verified with two clients, and documented from live code.

## Code / Security

- [x] Add `ws://`, `wss://`, and custom-path connection support for deployed clients.
- [x] Stop trusting client-supplied zone names; refresh zone from server world state before gated actions.
- [x] Fix fishing-start failure RPC argument count.
- [x] Persist equipped rod, bait, hook, and hook durability.
- [x] Send equipped gear state to clients on login.
- [x] Add basic fishing result guardrails against instant success RPCs.
- [ ] Replace client-authoritative movement with server-authoritative or server-validated movement if this grows beyond trusted friends.
- [ ] Strengthen fishing validation beyond timing guardrails if adversarial clients are in scope.

## Gameplay Verification

- [x] Playtest bait rarity/no-bait junk economy and sign off initial weights.
- [x] Verify 2-player fishing sync: cast, reel, result, animation, and no cross-player UI bleed.
- [x] Verify gear consumption in 2-player sessions: bait decrement, hook durability, break/re-equip, reconnect state.
- [x] Verify HUD and GearStatsPanel live refresh after bait/hook depletion.
- [x] Validate blackjack card rendering, backdrop, and flip animations in an exported build, including visual signoff.

## Visual / Content

- [x] Implement bobber visual with multiplayer sync.
- [x] Render caught fish/key/chest/junk sprites as normalized world catch popups using `FishData.icon` or `sprite_frame`.
- [x] Add bobber spawn splash animation.
- [x] Replace casino exterior with transparent style-matched art.
- [x] Add blackjack casino backdrop.
- [x] Add blackjack-only coin burst VFX on winning payouts.
- [x] Reposition zones after final building placement.
- [x] Finish water animation setup.
- [x] Confirm tilemap/building/water collision in a real play session.
- [x] Final spawn point pass.
- [x] Add final fish shop interior backdrop.
- [x] Assign remaining non-catch item icons on `.tres` resources and show them in shop rows.

## Release / Deployment

- [x] Confirm GHCR package visibility.
- [x] Confirm deployed clients can connect through `wss://fishserver.dudeltron14.win`.
- [x] Confirm Cloudflare Tunnel origin routing to the Docker game server.
- [x] Confirm Docker SQLite persistence through container restart/update.
- [x] Run Linux server export and Web export from CI or local Godot.
- [x] Update screenshots in `docs/screenshots/` for README.

Out of scope for this ship path: Windows Desktop export. The intended client is the Web export, backed by the Linux Docker server.

## Documentation

- [x] Update `README.md`, `TODO.md`, `FRAMEWORKS.md`, and `FISHING.md` for the July 2026 gameplay/art/deploy pass.
- [ ] Keep docs aligned after exported blackjack validation and the final world pass.
- [ ] After playtest signoff, move completed items from this checklist into a release note or done section.

## Post-Playtest

These are intentionally deferred until after the first closed beta playtest starts producing real economy feedback.

- [ ] Balance expanded 17-catch roster, payouts, and Baby Kraken 2.5 difficulty from closed beta data.
