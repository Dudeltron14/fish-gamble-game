# Ship Checklist

This is the current shipping bar for `fishing-tuning`. It intentionally uses the stricter review criteria: server-authoritative where it affects coins, deployable over WSS, verified with two clients, and documented from live code.

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

- [ ] Playtest bait rarity/no-bait junk economy and sign off weights.
- [ ] Verify 2-player fishing sync: cast, reel, result, animation, and no cross-player UI bleed.
- [ ] Verify gear consumption in 2-player sessions: bait decrement, hook durability, break/re-equip, reconnect state.
- [ ] Verify HUD and GearStatsPanel live refresh after bait/hook depletion.
- [ ] Validate blackjack card rendering in an exported build.

## Visual / Content

- [ ] Implement bobber visual with multiplayer sync.
- [ ] Render caught fish/key/chest/junk sprites in the result UI using `FishData.sprite_frame`.
- [ ] Reposition zones after final building placement.
- [ ] Finish water animation setup.
- [ ] Confirm tilemap/building/water collision in a real play session.
- [ ] Final spawn point pass.
- [ ] Assign item icons on `.tres` resources if item display surfaces use them.

## Release / Deployment

- [ ] Add Windows export preset if desktop local builds are part of ship.
- [ ] Confirm GHCR package visibility.
- [ ] Confirm VPS TLS and Nginx WSS proxy (`/ws`) configuration.
- [ ] Confirm Docker SQLite persistence through container restart/update.
- [ ] Run Linux server export and Web export from CI or local Godot.
- [ ] Update screenshots in `docs/screenshots/` for README.

## Documentation

- [ ] Keep `README.md`, `TODO.md`, `FRAMEWORKS.md`, and `FISHING.md` aligned with live values.
- [ ] After playtest signoff, move completed items from this checklist into a release note or done section.
