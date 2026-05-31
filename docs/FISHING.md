# Fishing System — Complete Reference

Last updated: 2026-05-30
All values sourced directly from live code and .tres resource files.

---

## Overview

Fishing is triggered by pressing **E** inside the **DockZone**. The server validates the zone, picks a fish, and deducts gear before the player sees the reel. The minigame runs client-side; the server only validates the final result.

---

## Stage Flow

```
Press E at dock → CAST → WAITING → REACT → REEL → RESULT
```

### Stage 1 — Cast

Hold **E** to fill a power bar, release to cast. The bar fills green toward 100%, then drains back if you hold too long (overshoot).

**Cast quality** = `cast_power / 100` at the moment of release (0.0 = terrible, 1.0 = perfect).

| Rod | Cast speed mult | Fill time |
|---|---|---|
| Starter Rod | ×1.0 | 1.67s |
| Angler's Rod | ×1.4 | 1.19s |
| Master Rod | ×1.8 | 0.93s |

**Cast quality effects (stacked on top of bait/rod):**
- **Rarity:** `cast_bonus = (quality − 0.5) × 0.2` → shifts weight from Common to Rare/Legendary
  - Perfect (1.0): Common −10%, Rare +7%, Legendary +3%
  - Terrible (0.0): Common +10%, Rare −7%, Legendary −3%
- **Wait timer:** Perfect cast → 1.5–3.5s wait. Terrible cast → 5.25–10.25s wait
- **React window:** Terrible cast reduces react window by up to 50%

---

### Stage 2 — Waiting

After casting, the player waits for a bite. During this stage the server assigns a fish and gear is consumed.

**Wait timer:** `randf_range(cast_min, cast_max) × bait.wait_modifier`

| Cast quality | Min wait | Max wait |
|---|---|---|
| Perfect (1.0) | 1.5s | 3.5s |
| Neutral (0.5) | 3.4s | 6.9s |
| Terrible (0.0) | 5.25s | 10.25s |

Bait `wait_modifier` multiplies this range further (see Bait section).

**Gear consumed here:** 1 bait use + 1 hook durability, regardless of minigame outcome.

---

### Stage 3 — React

Bite prompt appears. Player must press **E** within the window.

**React window:** `1.2 / (1 + max(0, difficulty−1) × 0.35) × (1 + hook.escape_reduction) × lerp(0.5, 1.0, cast_quality)`

| Fish | No hook, perfect cast | Golden Hook, perfect | No hook, terrible cast |
|---|---|---|---|
| Perch (0.6) | 1.20s | 1.50s | 0.60s |
| Bass (1.0) | 1.20s | 1.50s | 0.60s |
| Trout (1.6) | 0.99s | 1.24s | 0.50s |
| Pike (2.1) | 0.87s | 1.09s | 0.44s |
| Kraken (2.8) | 0.74s | 0.92s | 0.37s |

---

### Stage 4 — Reel

Core minigame. A 420px bar contains:
- **Green catch zone** — follows the fish
- **White cursor** — controlled by A/D keys

Fill the catch meter by keeping the cursor on the zone. The escape timer drains when you're off the zone.

#### Fish Movement

Fish speed **slides** randomly between a minimum and maximum, lerping smoothly toward new targets every 0.5–1.5s (independent of direction changes).

| Fish | Speed range | Avg speed |
|---|---|---|
| Perch (0.6) | 28–56 px/s | ~42 px/s |
| Bass (1.0) | 46–92 px/s | ~69 px/s |
| Trout (1.6) | 74–148 px/s | ~111 px/s |
| Pike (2.1) | 97–150 px/s | ~124 px/s |
| Kraken (2.8) | 52–150 px/s | ~101 px/s |

**Cursor speed:** 150 px/s — matches the maximum possible fish speed.

**Fish start position:** Scales with difficulty — easy fish spawn far from center (longer chase), hard fish spawn close (immediately erratic).

| Fish | Spawn distance from center |
|---|---|
| Perch (0.6) | 25–45% of bar |
| Bass (1.0) | 21–40% |
| Trout (1.6) | 16–35% |
| Pike (2.1) | 12–30% |
| Kraken (2.8) | 7–23% |

#### Fish Behaviour System

When the direction timer fires (every 0.6–1.6s), the fish picks a behaviour weighted by difficulty. Easy fish are more static; hard fish are more erratic.

| Behaviour | Easy fish | Hard fish | Description |
|---|---|---|---|
| **Flip direction** | 20% | 35% | Reverses movement |
| **Continue** | 15% | 25% | Keeps going same way |
| **Slow down** | 30% | 0% | Slides to ~15% of max speed for 1–2.5s |
| **Hover** | 20% | 0% | Nearly stops for 2–4s, barely moves |
| **Speed burst** | 5% | 25% | Darts to max speed for 0.2–0.6s |
| **Shimmy** | 0% | 15% | Rapid direction flicker with 0.1–0.25s timer |
| **Freeze then dash** | 10% | 0% | Stops briefly, then bolts in random direction |

**Edge bounce:** Fish bounces when the **edge of its catch zone** would leave the bar (not the fish centre). Catch zone always stays fully visible.

**LERP speed:** `FISH_SPEED_LERP = 2.5` — transitions feel smooth, not instant.

#### Catch Zone

`zone_width = (0.18 / difficulty) × 420px`

| Fish | Zone width | % of bar |
|---|---|---|
| Perch (0.6) | 126px | 30% |
| Bass (1.0) | 76px | 18% |
| Trout (1.6) | 47px | 11% |
| Pike (2.1) | 36px | 9% |
| Kraken (2.8) | 27px | 6.4% |

#### Catch Meter

- **Fills when on fish:** `0.35 × rod.line_strength /s`
- **Drains when off fish:** `0.35 × difficulty /s`

| Rod | Fill rate | Time to catch (perfect overlap) |
|---|---|---|
| Starter Rod | 0.35/s | 2.86s |
| Angler's Rod | 0.525/s | 1.91s |
| Master Rod | 0.77/s | 1.30s |

**Drain rate per fish:**

| Fish | Drain rate | Time to fully drain from 100% |
|---|---|---|
| Perch | 0.21/s | 4.76s |
| Bass | 0.35/s | 2.86s |
| Trout | 0.56/s | 1.79s |
| Pike | 0.74/s | 1.35s |
| Kraken | 0.98/s | 1.02s |

#### Escape Timer

**Starting value:** 3.0 seconds.

The escape timer fills and drains at the **same rate as the catch meter**. Fish escapes when escape timer hits 0. Fish is caught when catch meter hits 100%.

The status bar shows: `Losing the fish! 65% — 1.47s` (exact countdown to escape).
Bar colour: green when filling, orange→red when draining.

**Win:** catch meter → 100%
**Lose:** escape timer → 0

---

### Stage 5 — Result

Message appears with outcome. Player character plays **hook** animation on successful catch (plays once, pauses on last frame). Overlay closes after 2.5s.

---

## Fish Catalogue

All fish are `.tres` files in `src/resources/fish/`. Adding new fish requires only creating a file — no code changes.

**Payout formula:** `earned = floor(base_coin_value × catch_difficulty × hook.coin_multiplier)`

### Catchable Fish

| Fish | Rarity | Difficulty | Base value | Payout | + Golden Hook |
|---|---|---|---|---|---|
| Perch | common | 0.6 | 15c | **9c** | 11c |
| Largemouth Bass | uncommon | 1.0 | 20c | **20c** | 26c |
| Golden Trout | rare | 1.6 | 35c | **56c** | 72c |
| Northern Pike | rare | 2.1 | 35c | **73c** | 95c |
| Baby Kraken | legendary | 2.8 | 100c | **280c** | 364c |
| Sunken Chest | legendary | 2.2 | 150c | **330c** | 429c |
| Ancient Key | legendary | 2.5 | 150c | **375c** | 487c |

### Junk (Common Rarity — 0 Coins)

Junk appears in the common rarity pool. Without bait (95% common), fishing yields junk very frequently. Use bait to reduce common odds and stop pulling up trash.

| Item | Rarity | Payout | Note |
|---|---|---|---|
| Old Boot | common | 0c | Very easy to "catch" |
| Tin Can | common | 0c | Very easy to "catch" |
| Clump of Seaweed | common | 0c | Easiest possible |

---

## Rarity Selection (Server-Side)

The server selects a rarity tier, then picks a random fish of that rarity.

**Selection order:**
1. Start with bait `rarity_weights` (or default if no bait)
2. Apply rod `rarity_bonus` shift
3. Apply cast quality bonus/penalty
4. Normalise weights to sum to 1.0
5. Weighted random pick

### Default Weights (No Bait)

| Rarity | Probability |
|---|---|
| Common | **95%** — mostly junk + Perch |
| Uncommon | 5% |
| Rare | 0% |
| Legendary | 0% |

### Bait Weights

| Bait | Cost | Common | Uncommon | Rare | Legendary | Wait modifier |
|---|---|---|---|---|---|---|
| Worm | 5c | 70% | 22% | 7% | 1% | ×0.90 |
| Shiny Lure | 20c | 40% | 35% | 20% | 5% | ×0.75 |
| Magic Bait | 60c | **0%** | 30% | 40% | 30% | ×0.55 |

Magic Bait completely eliminates junk and common fish.

### Rod Rarity Bonus

```
weights["common"]    -= rarity_bonus
weights["rare"]      += rarity_bonus × 0.7
weights["legendary"] += rarity_bonus × 0.3
```

| Rod | rarity_bonus | Effect on Worm weights |
|---|---|---|
| Starter Rod | 0.00 | No change |
| Angler's Rod | 0.05 | Common −5%, Rare +3.5%, Legendary +1.5% |
| Master Rod | 0.12 | Common −12%, Rare +8.4%, Legendary +3.6% |

---

## Gear

### Rods — Permanent (never consumed)

| Rod | Price | Cast speed | Reel speed | Rarity bonus |
|---|---|---|---|---|
| Starter Rod | Free | ×1.0 | ×1.0 | 0% |
| Angler's Rod | 80c | ×1.4 | ×1.5 | +5% |
| Master Rod | 250c | ×1.8 | ×2.2 | +12% |

### Bait — Consumed 1 use per bite (win or lose)

Buying bait adds `uses_per_stack` to owned count.

| Bait | Price | Stack | Wait modifier | Pool |
|---|---|---|---|---|
| Worm | 5c | 10 uses | −10% | Common/Uncommon/Rare/Legendary |
| Shiny Lure | 20c | 10 uses | −25% | No dominant common |
| Magic Bait | 60c | 5 uses | −45% | Zero common, 30% legendary |

### Hooks — Durability depletes 1 per bite

When durability hits 0: one hook consumed from inventory, next auto-equips at full durability.

| Hook | Price | Durability | Coin multiplier | React bonus |
|---|---|---|---|---|
| Basic Hook | 15c (free starter) | 10 uses | ×1.0 | +10% |
| Golden Hook | 120c | 20 uses | ×1.3 | +25% |

**Equipping gear is free** — only bites consume gear.

### Starter Gear

New players receive on registration:
- Starter Rod (equipped)
- Worm ×1 (equipped)
- Basic Hook, 10 durability (equipped)

---

## HUD Display

```
Rod: Starter Rod   Bait: Worm ×3   Hook: Basic Hook 8/10
```

Press **Tab** in-game for the full Gear Modifiers panel showing exact multipliers, fish pool percentages, and volume sliders.

---

## Adding New Content

All item types are data-driven — no code changes needed. See `docs/FRAMEWORKS.md` for field-by-field guides and templates.

**Fish:** `src/resources/fish/_template.tres`
**Junk:** Same as fish — set `base_coin_value = 0` and `rarity = "common"`
**Chest/Key:** Same as fish — set `rarity = "legendary"` and high `base_coin_value`
