# Frameworks — How to extend the game

All game content is data-driven via Godot `.tres` Resource files.
**Adding content never requires code changes** — only creating or editing `.tres` files.

---

## Adding a new fish

1. Duplicate any file in `src/resources/fish/`
2. Rename it (e.g. `legendary_whale.tres`)
3. Open in Godot Inspector and set:

| Field | Description |
|---|---|
| `id` | Unique string key (must match filename convention) |
| `display_name` | Shown in UI on catch |
| `description` | Flavour text |
| `rarity` | `common` / `uncommon` / `rare` / `legendary` |
| `base_coin_value` | Coins awarded on catch (multiplied by tackle) |
| `catch_difficulty` | `1.0` = default. Higher = faster fish, smaller catch zone |
| `sprite_frame` | Frame index in `assets/free fish/free fish.png` |
| `icon` | Texture shown in shop/inventory (optional) |

`ItemRegistry` picks it up automatically on next launch. No code changes.

---

## Adding a new rod

Duplicate any file in `src/resources/rods/` and set:

| Field | Effect |
|---|---|
| `buy_price` | Cost in shop (0 = not for sale) |
| `cast_speed` | Multiplier on cast bar fill speed (1.0 = default) |
| `line_strength` | Reserved for future escape chance reduction |
| `rarity_bonus` | Shifts weight from `common` into `rare`/`legendary` pools |

---

## Adding new bait

Duplicate any file in `src/resources/baits/` and set:

| Field | Effect |
|---|---|
| `buy_price` | Cost per stack in shop |
| `uses_per_stack` | How many casts per purchase (display only for now) |
| `rarity_weights` | Dictionary — keys: `common`, `uncommon`, `rare`, `legendary`. Values must sum to ~1.0 |

Example — bait that only produces rare/legendary fish:
```
rarity_weights = {"common": 0.0, "uncommon": 0.1, "rare": 0.6, "legendary": 0.3}
```

---

## Adding new tackle

Duplicate any file in `src/resources/tackle/` and set:

| Field | Effect |
|---|---|
| `buy_price` | Cost in shop |
| `escape_reduction` | Reserved for future line_strength interaction |
| `coin_multiplier` | Multiplies `base_coin_value` on every catch (e.g. `1.3` = +30%) |

---

## Adding a new casino game

1. Create `src/scenes/casino/YourGame.tscn` + `YourGame.gd` (extend `CanvasLayer`, emit `completed` signal)
2. Create `src/server/YourGameServer.gd` (extend `Node`, handle RPCs)
3. Add to `GameServer.init_server()` script list
4. Add RPCs to `NetAPI.gd` (c2s_ + notify_ pattern)
5. Add a new zone to `World.tscn` and wire it in `World.gd`'s `_unhandled_input` match block

---

## Equipping items

Players equip from the Shop overlay. The server tracks equipped items in `PlayerSession`:
- `equipped_rod_id`
- `equipped_bait_id`
- `equipped_tackle_id`

These are restored from the inventory DB on each login (`AuthServer._load_equipped`).
The client mirrors them in `GameManager` (rod/bait/tackle `_id` fields) for HUD display.
