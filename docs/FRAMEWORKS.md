# Frameworks — How to Add Content

All game content is data-driven via Godot `.tres` Resource files.
Most item changes require only creating or duplicating a `.tres` file. Worm uses a curated fish pool in `FishingServer.gd`, so add code entries there if a new fish should appear through that bait.

`ItemRegistry` scans the resource folders at startup and registers everything automatically.
The shop, fishing system, and HUD all respond to whatever is registered.

> **Files starting with `_` are skipped by ItemRegistry** — this is how templates stay
> in the same folder without being loaded as real items.

---

## Quick Reference

| Item type | Folder | Template | Consumed? |
|---|---|---|---|
| Fish | `src/resources/fish/` | `_template.tres` | Never (caught) |
| Rod | `src/resources/rods/` | `_template.tres` | Never |
| Bait | `src/resources/baits/` | `_template.tres` | 1 use per bite |
| Hook/Tackle | `src/resources/tackle/` | `_template.tres` | 1 durability per bite |

---

## How to Add Any Item

1. Open the matching folder in Godot's FileSystem dock
2. Right-click **`_template.tres`** → **Duplicate**
3. Rename it (no leading underscore — e.g. `deep_sea_lure.tres`)
4. Select it → edit fields in the **Inspector**
5. Save (`Ctrl+S`)

The item appears in the shop on next launch (if `buy_price > 0`).

---

## Adding a Fish

**Template:** `src/resources/fish/_template.tres`

### Payout Formula

```
earned = floor(base_coin_value × catch_difficulty × hook.coin_multiplier)
```

`base_coin_value` is the **rarity tier base** — not a per-fish value.
`catch_difficulty` is the work multiplier that scales both the challenge AND the reward.

| Rarity | base_coin_value | Example payout at difficulty 1.0 |
|---|---|---|
| common | 15 | 15c |
| uncommon | 20 | 20c |
| rare | 35 | 35c × difficulty |
| legendary | 100 | 100c × difficulty |

### Fields

| Field | Type | Description |
|---|---|---|
| `id` | String | Unique snake_case key. Must be unique across all items. Matches filename by convention. |
| `display_name` | String | Shown in catch result message. |
| `description` | String | Flavour text (future shop display). |
| `buy_price` | int | Always `0` — fish are caught, not purchased. |
| `rarity` | String | `"common"` `"uncommon"` `"rare"` `"legendary"` — determines draw pool. |
| `base_coin_value` | int | Rarity tier base (see table above). **NOT the final payout** — multiplied by difficulty. |
| `catch_difficulty` | float | Controls zone size, fish speed, drain rate, react window, AND payout. See guide below. |
| `icon` | Texture2D | Preferred standalone transparent catch sprite. Use 64×64 PNGs for generated fish/key/chest art. |
| `sprite_frame` | int | Fallback frame index in `assets/free fish/free fish.png`. Set `-1` when only `icon` should be used. |

### Difficulty Reference

| `catch_difficulty` | Zone width | Speed range | Drain /s | React window | Payout (rare base 35c) |
|---|---|---|---|---|---|
| 0.6 | 126px (30%) | 28–56 px/s | 0.21/s | 1.20s | 21c |
| 1.0 | 76px (18%) | 46–92 px/s | 0.35/s | 1.20s | 35c |
| 1.6 | 47px (11%) | 74–134 px/s | 0.56/s | 0.99s | 56c |
| 2.1 | 36px (9%) | 83–150 px/s | 0.74/s | 0.87s | 73c |
| 2.5 | 30px (7.2%) | 83–150 px/s | 0.88/s | 0.79s | 87c |

> Speed caps at 150px/s (cursor speed) regardless of difficulty.
> React window is further modified by the equipped hook's `escape_reduction`.

Catch sprites shown above the player are normalized by visible alpha bounds, so transparent padding in generated art will not make the reward appear tiny. Clean generated catch art should still be transparent 64×64 PNGs.

---

## Adding a Rod

**Template:** `src/resources/rods/_template.tres`

Rods are permanent — **never consumed**.

### Fields

| Field | Type | Description |
|---|---|---|
| `id` | String | Unique key. |
| `display_name` | String | Shown in HUD and shop. |
| `buy_price` | int | `0` = starter item (hidden in shop). |
| `cast_speed` | float | Cast bar fill multiplier. `1.0` = 1.67s fill. `2.0` = 0.83s fill. |
| `line_strength` | float | Catch meter fill rate multiplier AND escape timer refill rate. `1.0` = 2.86s to catch. `2.2` = 1.30s. |
| `rarity_bonus` | float | Shifts fish probability toward rare/legendary. See formula. |

### Rarity Bonus Formula
```
weights["common"]    -= rarity_bonus
weights["rare"]      += rarity_bonus × 0.7
weights["legendary"] += rarity_bonus × 0.3
```
Applied after bait weights, before cast quality modifier. Stacks with both.

| `rarity_bonus` | Effect |
|---|---|
| 0.00 | No change (Starter Rod) |
| 0.05 | Subtle shift — common −5%, rare +3.5%, legendary +1.5% (Angler's Rod) |
| 0.12 | Strong shift — common −12%, rare +8.4%, legendary +3.6% (Master Rod) |
| 0.20 | Very strong shift |

---

## Adding Bait

**Template:** `src/resources/baits/_template.tres`

Bait is **consumed 1 use per bite** (when a fish is assigned), win or lose.
Buying adds `uses_per_stack` to owned count.

### Fields

| Field | Type | Description |
|---|---|---|
| `id` | String | Unique key. |
| `display_name` | String | Shown in HUD as `Bait: Worm ×5`. |
| `buy_price` | int | Cost per purchase. Each purchase adds `uses_per_stack` uses. |
| `rarity_weights` | Dictionary | Rarity pool probabilities. Keys: `"common"` `"uncommon"` `"rare"` `"legendary"`. Must sum to ≈1.0. Replaces default weights entirely. |
| `uses_per_stack` | int | Uses added per purchase (enforced server-side). |
| `wait_modifier` | float | Multiplier on bite wait timer. Stacks with cast quality penalty. |

### Wait Modifier Reference

The full wait time = `randf_range(cast_min, cast_max) × wait_modifier`

| `wait_modifier` | Effect | Bite wait at perfect cast |
|---|---|---|
| 1.00 | No change | 1.5–3.5s |
| 0.90 | 10% shorter (Worm) | 1.4–3.2s |
| 0.75 | 25% shorter (Glow Grub) | 1.1–2.6s |
| 0.55 | 45% shorter (Magic Bait) | 0.8–1.9s |
| 0.35 | 65% shorter (ultra premium) | 0.5–1.2s |

> Cast quality also affects wait time. Terrible cast range: 5.25–10.25s × wait_modifier.

### Rarity Weights Reference

```
Default (no bait): 50% junk, 50% starter common fish; no uncommon/rare/legendary pool
Worm data:         {common:0.85, uncommon:0.15, rare:0.00, legendary:0.00}
Glow Grub:         {common:0.45, uncommon:0.40, rare:0.14, legendary:0.01}
Magic Bait:        {common:0.025, uncommon:0.425, rare:0.40, legendary:0.15}
```

Runtime note: No bait and Worm currently use curated server-side pools instead of the dynamic rarity picker. No bait is capped to junk/common starter catches. Worm is capped to junk/common/uncommon starter catches. Glow Grub and Magic Bait use the normal dynamic picker.

---

## Adding a Hook (Tackle)

**Template:** `src/resources/tackle/_template.tres`

Hooks lose **1 durability per bite**. When durability hits 0, 1 hook is consumed from inventory.
If more are owned, the next auto-equips at full durability.
**Equipping a hook does NOT consume it** — only bites do.

### Fields

| Field | Type | Description |
|---|---|---|
| `id` | String | Unique key. |
| `display_name` | String | Shown in HUD as `Hook: Golden Hook 18/20`. |
| `buy_price` | int | Cost per hook. |
| `coin_multiplier` | float | Multiplies fish payout per catch. `1.0` = no bonus. `1.3` = +30%. |
| `durability` | int | Bites before hook breaks. Shown as current/max in HUD. |
| `escape_reduction` | float | Widens the react window (time to press E on bite). |

### Coin Multiplier Reference
```
earned = floor(fish.base_coin_value × fish.difficulty × coin_multiplier)
```
| `coin_multiplier` | Kraken payout | Perch payout |
|---|---|---|
| 1.0 | 650c (Basic Hook) | 9c |
| 1.15 | 287c (Shiny Lure) | 10c |
| 1.3 | 845c (Golden Hook) | 11c |
| 1.5 | 375c | 13c |
| 2.0 | 500c | 18c |

### Escape Reduction Reference
React window = `1.2 / (1 + max(0, difficulty−1) × 0.35) × (1 + escape_reduction)`

| `escape_reduction` | Kraken window (no cast penalty) |
|---|---|
| 0.00 | 0.79s |
| 0.10 | 0.87s (Basic Hook) |
| 0.18 | 0.93s (Shiny Lure) |
| 0.25 | 0.98s (Golden Hook) |
| 0.50 | 1.18s |

---

## Shop Visibility

Any item with `buy_price > 0` **automatically appears in the shop**, sorted by price.
Items with `buy_price = 0` are hidden from the shop but can be equipped if owned.

---

## Starter Items

New players receive on registration:

| Item | Qty |
|---|---|
| `starter_rod` | 1 (auto-equipped) |
| `worm` | 10 uses / one stack (auto-equipped) |
| `basic_hook` | 1 hook at full durability (auto-equipped) |

To change starter items: edit the constants and helpers in `src/autoloads/GameServer.gd`; `AuthServer._ensure_starter_items()` grants or repairs them for database accounts.

---

## Summary: Code vs. No-Code

| Action | Requires code? |
|---|---|
| Add new fish | Usually no - duplicate `_template.tres`; add to the curated Worm pool in code only if desired |
| Add new rod | No - duplicate `_template.tres` |
| Add new bait | No - duplicate `_template.tres` |
| Add new hook | No - duplicate `_template.tres` |
| Change any stat | No - edit `.tres` in Inspector |
| Change rarity base payout | No - edit `base_coin_value` |
| Change difficulty | No - edit `catch_difficulty` |
| Add a new item category | Yes - new Resource class + server handler |
| Change fishing validation/security model | Yes - server/client protocol change |
