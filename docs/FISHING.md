# Fishing System — Complete Reference

Last updated: 2026-05-30  
All values sourced directly from live code and .tres resource files.

---

## Overview

Fishing is triggered by pressing **E** while inside the **DockZone**. The server
validates the zone, picks a fish, and deducts gear — all before the player sees
the reel. The minigame runs entirely client-side; the server only validates the
final result (caught / missed).

---

## Stage Flow

```
Press E at dock → CAST → WAITING → REACT → REEL → RESULT
```

### Stage 1 — Cast

The player holds **E** to fill a power bar, then releases to cast.

| Variable | Value |
|---|---|
| Base fill speed | 60 units/s |
| Bar size | 100 units |
| Default time to fill | **1.67 seconds** |

**Rod `cast_speed` multiplies the fill rate:**

| Rod | cast_speed | Fill rate | Time to fill |
|---|---|---|---|
| Starter Rod | ×1.0 | 60 u/s | 1.67s |
| Angler's Rod | ×1.4 | 84 u/s | 1.19s |
| Master Rod | ×1.8 | 108 u/s | 0.93s |

> The power value itself has no gameplay effect beyond triggering the cast.
> Casting distance as a mechanic is not yet wired.

---

### Stage 2 — Waiting

After casting, the player waits for a bite.

| Variable | Value |
|---|---|
| Wait duration | **1.5 – 3.5 seconds** (uniform random) |
| Server action | Picks fish (see Rarity Selection below) |
| Gear consumed | **1 bait use + 1 hook durability** (happens here, win or lose) |

---

### Stage 3 — React

A bite prompt appears. The player must press **E** within the window.

| Variable | Value |
|---|---|
| React window | **1.5 seconds** |
| Miss penalty | Fish escapes, round ends |

---

### Stage 4 — Reel

The core minigame. A 420px horizontal bar contains:
- A **green catch zone** (follows the fish)
- A **white cursor** (controlled by player via A/D)

The player must keep the cursor overlapping the catch zone to fill the **catch
meter**. If the cursor leaves the zone, the meter drains. The round ends when
the meter reaches 100% (caught) or the fish swims off either edge (escaped).

#### Fish Movement

| Parameter | Value |
|---|---|
| Base speed formula | `0.1275 × difficulty` normalized units/s |
| Bar width | 420 px |
| Max fish speed (Kraken) | `0.1275 × 2.8 = 0.357/s` = **150 px/s** |
| Direction change timer | Every **0.6 – 1.6s** randomly |
| Direction reset on edge bounce | Every **0.5 – 1.2s** |
| Starting position | Centre of bar (0.5) |

**The cursor speed (150 px/s) equals the maximum fish speed**, so a skilled
player can always keep up with any fish.

Fish speeds by species:

| Fish | Difficulty | Speed (norm/s) | Speed (px/s) |
|---|---|---|---|
| Perch | 0.6 | 0.077 | 32 px/s |
| Bass | 1.0 | 0.128 | 54 px/s |
| Golden Trout | 1.6 | 0.204 | 86 px/s |
| Northern Pike | 1.8 | 0.230 | 96 px/s |
| Baby Kraken | 2.8 | 0.357 | 150 px/s |

#### Catch Zone Width

`zone_width = (0.18 / difficulty) × 420 px`

| Fish | Difficulty | Zone width | % of bar |
|---|---|---|---|
| Perch | 0.6 | 126 px | 30% |
| Bass | 1.0 | 75.6 px | 18% |
| Golden Trout | 1.6 | 47 px | 11% |
| Northern Pike | 1.8 | 42 px | 10% |
| Baby Kraken | 2.8 | 27 px | 6.4% |

#### Catch Meter — Fill Rate (in zone)

`fill_rate = 0.35 × rod.line_strength per second`

| Rod | line_strength | Fill rate | Time to catch (perfect play) |
|---|---|---|---|
| Starter Rod | 1.0 | 0.35/s | **2.86s** in zone |
| Angler's Rod | 1.5 | 0.525/s | **1.91s** in zone |
| Master Rod | 2.2 | 0.77/s | **1.30s** in zone |

#### Catch Meter — Drain Rate (out of zone)

`drain_rate = 0.35 × fish.difficulty per second`

| Fish | Difficulty | Drain rate | Time to drain from 100% |
|---|---|---|---|
| Perch | 0.6 | 0.21/s | 4.76s |
| Bass | 1.0 | 0.35/s | 2.86s |
| Golden Trout | 1.6 | 0.56/s | 1.79s |
| Northern Pike | 1.8 | 0.63/s | 1.59s |
| Baby Kraken | 2.8 | 0.98/s | 1.02s |

#### Escape — How the Fish Gets Away

The fish escapes (round fails) if `fish_pos` reaches 0.0 or 1.0 (either edge
of the bar). This is separate from the catch meter drain — even a full meter
won't save you if you let the fish reach the edge while not in the zone.

#### UI Feedback

| State | Bar colour | Status text |
|---|---|---|
| Cursor in zone | Green | `Reeling in… 65%` |
| Cursor out of zone | Orange → Red | `Losing the fish! 65% — 1.8s` |

The escape countdown (`X.Xs`) shows exactly how long until the meter hits 0 at
the current drain rate if the player does not re-enter the zone.

---

### Stage 5 — Result

A message bounces onto screen with the outcome. The overlay closes after
**2.5 seconds** and the player returns to the world. The player character
plays the **hook** animation on a successful catch (plays once, pauses on last
frame).

---

## Fish Catalogue

All fish are defined as `.tres` files in `src/resources/fish/`. Adding a new
fish requires only creating a new file — no code changes.

| Fish | Rarity | Difficulty | Base coins | Catch zone | Drain rate |
|---|---|---|---|---|---|
| Perch | common | 0.6 | 8c | 30% | 0.21/s |
| Largemouth Bass | uncommon | 1.0 | 20c | 18% | 0.35/s |
| Golden Trout | rare | 1.6 | 55c | 11% | 0.56/s |
| Northern Pike | rare | 1.8 | 70c | 10% | 0.63/s |
| Baby Kraken | legendary | 2.8 | 300c | 6.4% | 0.98/s |

**Coins earned = `floor(base_coin_value × hook.coin_multiplier)`**

---

## Rarity Selection (Server-Side)

The server picks which rarity tier to draw from before sending the fish to the
client. The bait's `rarity_weights` dictionary sets the base probabilities.
The equipped rod's `rarity_bonus` then shifts weight from common into rare/legendary.

### Default weights (no bait equipped)
| Rarity | Probability |
|---|---|
| common | 65% |
| uncommon | 25% |
| rare | 9% |
| legendary | 1% |

### Bait weights

| Bait | Cost | Common | Uncommon | Rare | Legendary | Uses |
|---|---|---|---|---|---|---|
| Worm | 5c | 70% | 22% | 7.5% | 0.5% | 1 per cast |
| Shiny Lure | 20c | 45% | 35% | 17% | 3% | 1 per cast |
| Magic Bait | 60c | 20% | 35% | 30% | 15% | 1 per cast |

### Rod rarity bonus

After bait weights are applied, `rarity_bonus` shifts weight:

```
weights["common"]    -= rarity_bonus
weights["rare"]      += rarity_bonus × 0.7
weights["legendary"] += rarity_bonus × 0.3
```

| Rod | rarity_bonus | Effect on Worm weights |
|---|---|---|
| Starter Rod | 0.0 | No change |
| Angler's Rod | 0.05 | common 65%→60%, rare 7.5%→11%, legendary 0.5%→2% |
| Master Rod | 0.12 | common 70%→58%, rare 7.5%→15.9%, legendary 0.5%→4.1% |

After a rarity tier is selected, a random fish of that rarity is chosen from
all registered fish.

---

## Gear

All gear is defined as `.tres` files. Adding new items requires only creating
a new file — no code changes needed. Gear is consumed **during the waiting
stage** (when a fish bites), regardless of whether the minigame is won or lost.

### Rods — `src/resources/rods/`

Rods are permanent equipment. They are not consumed.

| Rod | Cost | cast_speed | line_strength | rarity_bonus |
|---|---|---|---|---|
| Starter Rod | Free (starter) | ×1.0 | ×1.0 | 0.0 |
| Angler's Rod | 80c | ×1.4 | ×1.5 | 0.05 |
| Master Rod | 250c | ×1.8 | ×2.2 | 0.12 |

- **cast_speed** — multiplies the cast bar fill rate (faster = less hold time)
- **line_strength** — multiplies the catch meter fill rate in-zone (faster reel)
- **rarity_bonus** — shifts fish probability toward rare/legendary tiers

> `line_strength` also has an `escape_reduction` interaction planned but not
> yet implemented (see Unwired Stats below).

### Bait — `src/resources/baits/`

One bait is consumed each time a fish bites (entering the waiting stage).
When bait runs out the slot clears and default weights are used.

| Bait | Cost | common | uncommon | rare | legendary |
|---|---|---|---|---|---|
| Worm | 5c | 70% | 22% | 7.5% | 0.5% |
| Shiny Lure | 20c | 45% | 35% | 17% | 3% |
| Magic Bait | 60c | 20% | 35% | 30% | 15% |

> `uses_per_stack` is stored on each bait resource but not yet enforced —
> each purchase always adds 1 to owned count regardless of stack size.

### Hooks (Tackle) — `src/resources/tackle/`

Hooks lose 1 durability each time a fish bites. When durability reaches 0 the
hook is consumed from inventory; if more hooks are owned the next one
auto-equips at full durability. When the last hook breaks the slot clears.

| Hook | Cost | coin_multiplier | durability | escape_reduction |
|---|---|---|---|---|
| Basic Hook | 15c (free starter) | ×1.0 | 10 uses | 0.10 (unwired) |
| Golden Hook | 120c | ×1.3 (+30%) | 20 uses | 0.25 (unwired) |

- **coin_multiplier** — multiplies `base_coin_value` on every successful catch
- **durability** — number of bites before the hook breaks
- **escape_reduction** — stored but not yet wired (see Unwired Stats)

---

## Gear Consumption Summary

| Gear | When consumed | Amount |
|---|---|---|
| Bait | Each bite (waiting stage) | 1 unit from owned count |
| Hook durability | Each bite (waiting stage) | −1 durability |
| Hook (item) | When durability hits 0 | 1 unit from owned count |
| Rod | Never | — |

---

## HUD Display

While in the world the HUD shows:

```
Rod: Starter Rod   Bait: Worm ×3   Hook: Basic Hook 8/10
```

- **Bait**: item name + owned count (updates live as bait is consumed)
- **Hook**: item name + current/max durability (updates live after each bite)
- **—** when a slot is empty

---

## Coins Formula

```
earned = floor(fish.base_coin_value × hook.coin_multiplier)
```

| Fish | No hook | Basic Hook | Golden Hook |
|---|---|---|---|
| Perch (8c) | 8c | 8c | 10c |
| Bass (20c) | 20c | 20c | 26c |
| Trout (55c) | 55c | 55c | 71c |
| Pike (70c) | 70c | 70c | 91c |
| Kraken (300c) | 300c | 300c | **390c** |

---

## Unwired Stats (Backlog)

These values are stored in .tres files and passed to the server but not yet
applied to gameplay logic.

| Stat | Lives on | Intended effect |
|---|---|---|
| `escape_reduction` | TackleData | Reduce chance fish escapes at bar edge |
| `line_strength` (secondary) | RodData | Also intended to interact with escape_reduction |
| `uses_per_stack` | BaitData | Per-purchase stack size (currently always 1 per buy) |

---

## Adding Content

To add a new fish, bait, rod, or hook:

1. Duplicate any existing `.tres` file in the matching `src/resources/` folder
2. Change `id`, `display_name`, and stats
3. Save — `ItemRegistry` picks it up automatically on next launch

No code changes are required.
