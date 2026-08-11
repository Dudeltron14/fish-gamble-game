# Fishing content packs

Fishing content is data-driven so new islands do not require changes to the catch server.

## Add an island

1. Add its map scene and one or more `Area2D` fishing zones.
2. Create a `FishingLocationData` resource in `src/resources/locations/`.
3. Put fish ids in `fish_ids`; use `day_modifiers` and `night_modifiers` for local tuning.
4. Add fish, rod, bait, and tackle resources with location tags and approved sprites.
5. Add optional NPC/quest/boss content in the island scene.

`FishingServer` resolves location, phase, rarity, time tags, and equipment effects from resources. Keep island-specific rules out of that script.

## Resource requirements

- Fish: `family`, `location_tags`, `time_tags`, size/weight range, rarity, value, difficulty, sprite.
- Bait: optional family/location/time affinities and size bonus.
- Rod/tackle: existing stats plus optional effect tags.
- Location: fish ids, habitat, rarity weights, and day/night modifiers.

The starter location is `starter_harbor`. Future locations remain dormant until their map and final assets are ready.

For deterministic local QA, set `BRINDLE_LOCAL_TIME_PHASE=day` or `night`. A future test
location can be selected with `BRINDLE_LOCAL_FISHING_ZONE=<zone_name>` without editing
`FishingServer.gd`.
