# Frameworks — How to Add Content

All game content is data-driven via Godot `.tres` Resource files.
**Adding any item type requires only creating or duplicating a `.tres` file — zero code changes.**

`ItemRegistry` scans the resource folders at startup and registers everything automatically.
The shop, fishing system, and HUD all respond to whatever is registered.

---

## Quick Reference

| Item type | Folder | Base class | Consumed on cast? |
|---|---|---|---|
| Fish | `src/resources/fish/` | `FishData` | Never (caught, not consumed) |
| Rod | `src/resources/rods/` | `RodData` | Never |
| Bait | `src/resources/baits/` | `BaitData` | Yes — 1 use per bite |
| Hook/Tackle | `src/resources/tackle/` | `TackleData` | 1 durability per bite |

---

## How to Add Any Item

1. Open the matching folder in Godot's FileSystem dock
2. Right-click an existing `.tres` file → **Duplicate**
3. Rename it (e.g. `deep_sea_lure.tres`)
4. Select it → edit fields in the **Inspector**
5. Save (`Ctrl+S`)

That's it. The item appears in the shop on next launch (if `buy_price > 0`).

---

## Adding a Fish

**Folder:** `src/resources/fish/`  
**Template:** duplicate `common_perch.tres`

### Fields

| Field | Type | Description |
|---|---|---|
| `id` | String | Unique key. Must match filename convention. Used everywhere in code. |
| `display_name` | String | Shown in catch result and UI. |
| `description` | String | Flavour text (not currently displayed, future use). |
| `icon` | Texture2D | Optional. Item icon for shop/inventory. |
| `buy_price` | int | Set to `0` — fish are caught, not bought. |
| `sell_price` | int | Not currently used. |
| `rarity` | String (enum) | `"common"`, `"uncommon"`, `"rare"`, or `"legendary"`. Determines which rarity pool this fish enters. |
| `base_coin_value` | int | Coins awarded on catch. Multiplied by hook's `coin_multiplier`. |
| `catch_difficulty` | float | Scales the reel minigame. `1.0` = default. Higher = faster fish, smaller catch zone, faster drain rate. |
| `sprite_frame` | int | Frame index in `assets/free fish/free fish.png`. |

### Rarity guide
| Rarity | When fish is selected |
|---|---|
| `common` | Standard pool; high probability with cheap bait |
| `uncommon` | Moderate probability; boosted by better bait/rod |
| `rare` | Low probability; requires good bait + rod + cast |
| `legendary` | Very rare; meaningfully boosted by Magic Bait, Master Rod, and perfect cast |

### Difficulty guide
| `catch_difficulty` | Fish speed | Catch zone | Drain rate | Feel |
|---|---|---|---|---|
| 0.5 | Very slow | 36% bar | 0.18/s | Trivial |
| 1.0 | Moderate | 18% bar | 0.35/s | Standard challenge |
| 2.0 | Fast | 9% bar | 0.70/s | Hard |
| 3.0 | Very fast (cursor limit) | 6% bar | 1.05/s | Extreme |

### Example — Ultra-Rare Megafish
```ini
[resource]
id = "megafish"
display_name = "Megafish"
description = "Ancient. Massive. Angry."
buy_price = 0
sell_price = 0
rarity = "legendary"
base_coin_value = 500
catch_difficulty = 3.0
sprite_frame = 5
```

---

## Adding a Rod

**Folder:** `src/resources/rods/`  
**Template:** duplicate `starter_rod.tres`

Rods are permanent equipment. They are **never consumed**.

### Fields

| Field | Type | Description |
|---|---|---|
| `id` | String | Unique key. |
| `display_name` | String | Shown in HUD and shop. |
| `description` | String | Shop flavour text. |
| `icon` | Texture2D | Optional item icon. |
| `buy_price` | int | Cost in shop. Set to `0` for starter items. |
| `sell_price` | int | Not currently used. |
| `cast_speed` | float | Multiplies cast bar fill rate. `1.0` = 1.67s to fill. `2.0` = 0.83s. |
| `line_strength` | float | Multiplies catch meter fill rate in-zone. `1.0` = 2.86s to catch. `2.0` = 1.43s. |
| `rarity_bonus` | float | Shifts rarity weight from `common` into `rare`/`legendary`. `0.0` = no shift. `0.10` ≈ Angler rod. `0.20` = very strong shift. |

### How rarity_bonus works
```
weights["common"]    -= rarity_bonus
weights["rare"]      += rarity_bonus × 0.7
weights["legendary"] += rarity_bonus × 0.3
```
Applied after bait weights and before cast quality modifier. Stacks with everything.

> **Unwired:** `line_strength` is also intended to interact with `escape_reduction` on hooks — not yet implemented.

### Example — Legendary Fishing Pole
```ini
[resource]
id = "legend_pole"
display_name = "Legend's Pole"
description = "Forged from a Kraken's spine."
buy_price = 800
sell_price = 300
cast_speed = 2.2
line_strength = 3.0
rarity_bonus = 0.18
```

---

## Adding Bait

**Folder:** `src/resources/baits/`  
**Template:** duplicate `worm.tres`

Bait is **consumed one use per bite** (when a fish is assigned), win or lose.
Buying a bait adds `uses_per_stack` to the player's owned count.

### Fields

| Field | Type | Description |
|---|---|---|
| `id` | String | Unique key. |
| `display_name` | String | Shown in HUD as `Bait: Shiny Lure ×5`. |
| `description` | String | Shop flavour text. |
| `icon` | Texture2D | Optional item icon. |
| `buy_price` | int | Cost per purchase. Each purchase adds `uses_per_stack` uses. |
| `sell_price` | int | Not currently used. |
| `rarity_weights` | Dictionary | Rarity pool probabilities. Keys: `"common"`, `"uncommon"`, `"rare"`, `"legendary"`. Values must sum to ≈ 1.0. **Replaces default weights entirely.** |
| `uses_per_stack` | int | How many uses are added per purchase. Enforced server-side. |
| `wait_modifier` | float | Multiplier on bite wait timer. `< 1.0` = fish bite sooner. `1.0` = no change. Applied on top of cast quality penalty (multiplicative). |

### Rarity weights guide
```ini
# Default (no bait) — baseline
{"common": 0.65, "uncommon": 0.25, "rare": 0.09, "legendary": 0.01}

# Worm — slight improvement
{"common": 0.70, "uncommon": 0.22, "rare": 0.075, "legendary": 0.005}

# Shiny Lure — meaningful rare boost
{"common": 0.45, "uncommon": 0.35, "rare": 0.17, "legendary": 0.03}

# Magic Bait — strong rare/legendary boost
{"common": 0.20, "uncommon": 0.35, "rare": 0.30, "legendary": 0.15}
```

### Wait modifier guide
| `wait_modifier` | Effect |
|---|---|
| 1.0 | No change (default) |
| 0.90 | 10% shorter wait (Worm) |
| 0.75 | 25% shorter wait (Lure) |
| 0.55 | 45% shorter wait (Magic Bait) |
| 0.30 | 70% shorter wait (ultra premium) |

### Example — Deep Sea Lure
```ini
[resource]
id = "deep_sea_lure"
display_name = "Deep Sea Lure"
description = "Glows in the dark. Legendary fish investigate."
buy_price = 120
sell_price = 40
rarity_weights = {"common": 0.05, "uncommon": 0.25, "rare": 0.45, "legendary": 0.25}
uses_per_stack = 3
wait_modifier = 0.65
```

---

## Adding a Hook (Tackle)

**Folder:** `src/resources/tackle/`  
**Template:** duplicate `basic_hook.tres`

Hooks lose **1 durability per bite** (regardless of minigame outcome).
When durability hits 0, one hook is consumed from inventory.
If more hooks are owned, the next auto-equips at full durability.

### Fields

| Field | Type | Description |
|---|---|---|
| `id` | String | Unique key. |
| `display_name` | String | Shown in HUD as `Hook: Golden Hook 18/20`. |
| `description` | String | Shop flavour text. |
| `icon` | Texture2D | Optional item icon. |
| `buy_price` | int | Cost per hook in shop. |
| `sell_price` | int | Not currently used. |
| `coin_multiplier` | float | Multiplies `base_coin_value` on every successful catch. `1.0` = no bonus. `1.3` = +30% coins. |
| `durability` | int | Total uses before the hook breaks. Shown as `N/max` in HUD. |
| `escape_reduction` | float | Extends the react window (time to press E on bite). `0.10` = +10% longer window. `0.25` = +25%. Scales with fish difficulty. |

### Example — Enchanted Hook
```ini
[resource]
id = "enchanted_hook"
display_name = "Enchanted Hook"
description = "Blessed by a sea witch. Very durable."
buy_price = 300
sell_price = 100
escape_reduction = 0.40
coin_multiplier = 1.6
durability = 50
```

---

## Shop Visibility

Any item with `buy_price > 0` **automatically appears in the shop**, sorted by price.
Items with `buy_price = 0` (starter items) are invisible in the shop but can be equipped if owned.

---

## Starter Items

New players receive these automatically on registration:

| Item | Quantity |
|---|---|
| `starter_rod` | 1 (equipped automatically) |
| `worm` | 1 use (equipped automatically) |
| `basic_hook` | 1 hook (equipped automatically) |

To change starter items, edit `AuthServer._give_starter_items()` in `src/server/AuthServer.gd`.

---

## Summary: What Requires Code vs. What Doesn't

| Action | Requires code? |
|---|---|
| Add new fish | ❌ No — just a .tres file |
| Add new rod | ❌ No — just a .tres file |
| Add new bait | ❌ No — just a .tres file |
| Add new hook | ❌ No — just a .tres file |
| Add a new **item category** (e.g. potions) | ✅ Yes — new Resource class + server handler |
| Change a new item's **shop price** | ❌ No — edit `buy_price` in Inspector |
| Change bait wait modifier | ❌ No — edit `wait_modifier` in Inspector |
| Change hook durability | ❌ No — edit `durability` in Inspector |
| Wire `escape_reduction` | ✅ Yes — one-line change in FishingServer |
| Wire `uses_per_stack` for rods/hooks | ✅ Yes — currently only enforced for bait |
