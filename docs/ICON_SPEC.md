# Gear Stats Panel — Icon Generation Spec

## Art Style Reference

The game uses **top-down pixel art** in the style of the ForgottenMemories tileset.
The world features bright, saturated colours, 1px dark outlines on all elements,
and a warm friendly aesthetic (colourful buildings, sandy/stone terrain, autumn trees).

All icons must match this style precisely.

---

## Technical Requirements (apply to ALL icons)

| Property | Value |
|---|---|
| Format | PNG with transparent background |
| Canvas size | **32 × 32 pixels** |
| Art style | **Pixel art** — hard pixel edges, no anti-aliasing, no blur |
| Outline | 1px dark outline (#1A1A2E or #222222) on all solid shapes |
| Background | Fully transparent (alpha = 0) |
| Colour depth | Indexed or 32-bit RGBA, no gradients |
| Shading | Flat with 1–2 highlight/shadow pixels max — simple, readable at small size |

---

## Global Colour Palette

These colours appear in the game world and UI. Use them as your base palette.

| Role | Hex | Usage |
|---|---|---|
| Dark outline | `#1A1A2E` | All outlines |
| UI panel background | `#1C2333` | Reference for contrast |
| Sand/tan | `#C4A86B` | Terrain reference |
| Stone grey | `#8E8E8E` | Terrain reference |
| Grass green | `#4E9B4E` | World vegetation |
| Water blue | `#4AA4D5` | World water |
| Building blue (shop) | `#1E7FD4` | World building reference |
| Building purple (casino) | `#8B44B0` | World building reference |
| Warm gold | `#FFD700` | Legendary / coin colours |
| Warm amber | `#E8923C` | Rod / hook accent |

---

## Icons

### Category Header Icons (larger, more detailed — 20×20 content in 32×32 canvas)

---

### `icon_rod.png`
**Meaning:** Rod category header  
**UI colour accent:** `#E8A04A` (warm amber — matches rod header label)  
**Description:** A classic fishing rod viewed at an angle. A long tapered stick (cork handle at bottom-left, thin tip at top-right) with a curved fishing line arcing from the tip. The reel is a small circle mid-rod. Colours: warm brown handle `#8B5A2B`, tan rod `#C48A3A`, silver reel `#AAAAAA`, blue line `#4AA4D5`. 1px dark outline throughout.

---

### `icon_bait.png`
**Meaning:** Bait category header  
**UI colour accent:** `#66CC66` (green — matches bait header label)  
**Description:** A plump worm curled into a loose S-shape. Round body segments visible. Colours: pinkish-red body `#CC4444`, slightly lighter segment highlights `#DD6666`, dark outline. Simple and clearly readable.

---

### `icon_hook.png`
**Meaning:** Hook category header  
**UI colour accent:** `#E07840` (orange — matches hook header label)  
**Description:** A fishhook shape — a J-curve with a small barb at the tip and an eye loop at the top. Silver/steel coloured: `#C0C0C0` body, `#888888` shadow side, white `#FFFFFF` highlight pixel. Dark outline.

---

### Stat Row Icons (smaller, simple silhouettes — 14×14 content in 32×32 canvas, centred)

---

### `icon_cast_speed.png`
**Meaning:** How fast the cast power bar fills  
**Description:** A small lightning bolt. A clean angular bolt shape pointing downward-right. Colour: bright yellow `#FFE033` with orange `#FF8C00` shadow side. Dark outline.

---

### `icon_reel_speed.png`
**Meaning:** How fast the catch meter fills when cursor is on the fish  
**Description:** A circular arrow / spinning reel — a circle with a gap and an arrowhead showing rotation. Colour: light blue `#66AAFF` main body, darker blue `#3366CC` shadow. Dark outline. Represents the fishing reel spinning.

---

### `icon_rarity_bonus.png`
**Meaning:** Rod's shift of fish probability toward rare/legendary  
**Description:** A 4-pointed sparkle / star shape. A bright central point with four diamond-shaped rays extending left/right/up/down. Colour: gold `#FFD700` with amber `#CC8800` on shadow rays. Dark outline.

---

### `icon_bite_speed.png`
**Meaning:** How much bait reduces the wait time before a fish bites  
**Description:** A simple clock face — a circle with a 12 o'clock mark and clock hands pointing to roughly 10:10 (or just one hand pointing at 10 o'clock to show speed). Colour: white/cream `#EEEECC` clock face, dark `#333333` hands, `#CC4444` outer ring. Dark outline.

---

### `icon_durability.png`
**Meaning:** How many uses the hook has before it breaks  
**Description:** A small shield shape — a classic heraldic shield (rounded bottom point, straight sides, flat top). Colour: steel blue `#5577AA` main face, `#3355AA` shadow lower-half, `#88AACC` highlight top-left corner. Dark outline.

---

### `icon_coin_bonus.png`
**Meaning:** The hook's multiplier on fish payout coins  
**Description:** A round coin seen face-on with a small × symbol in the centre (to indicate multiplier). Colour: gold `#FFD700` face, amber `#CC9900` outer ring, dark `#1A1A2E` × symbol. Dark outline.

---

### `icon_react_window.png`
**Meaning:** The hook's bonus to the react window (time to press E on a bite)  
**Description:** An exclamation mark inside a small rounded rectangle (like an alert badge). The ! is bold and centred. Colour: bright red `#EE3333` background badge, white `#FFFFFF` exclamation mark. Dark outline.

---

### `icon_cast_hint.png`
**Meaning:** Reminder that perfect cast adds +10% to rare/legendary  
**Description:** A small fishing rod (simplified, like icon_rod.png but tiny) with a sparkle above the tip. Rod colour: tan `#C48A3A`. Sparkle: gold `#FFD700`. Dark outline. Conveys "good cast = better fish."

---

### Fish Rarity Tier Icons (for the pool row — 12×12 content in 32×32 canvas, centred)

These four icons appear in a horizontal row showing the bait's fish pool breakdown.
They should form a matching set — same base shape, different colour.
**Suggested shape:** A small fish silhouette (simple side-view — oval body, small tail fin, small dorsal fin, dot eye).

---

### `icon_tier_common.png`
**Rarity:** Common  
**Colour:** Greyed-out / desaturated — body `#888888`, fin `#666666`, belly `#AAAAAA`, eye `#444444`. Dark outline.  
**Feel:** Plain, unremarkable. The fish nobody brags about catching.

---

### `icon_tier_uncommon.png`
**Rarity:** Uncommon  
**Colour:** Green — body `#44AA44`, fin `#228822`, belly `#66CC66`, eye `#1A1A2E`. Dark outline.  
**Feel:** A bit special. Worth mentioning.

---

### `icon_tier_rare.png`
**Rarity:** Rare  
**Colour:** Blue — body `#4477DD`, fin `#2255BB`, belly `#6699FF`, eye `#1A1A2E`. Dark outline.  
**Feel:** Exciting. Players will react.

---

### `icon_tier_legendary.png`
**Rarity:** Legendary  
**Colour:** Gold with a glow suggestion — body `#FFB800`, fin `#CC8800`, belly `#FFE066`, eye `#1A1A2E`. Add 2–3 tiny gold sparkle pixels around the fish. Dark outline.  
**Feel:** Rare and impressive. The crown jewel.

---

## Delivery

- Save all 14 files to: **`assets/ui_icons/`**
- Filename must match exactly (lowercase, underscores, `.png` extension)
- After adding files, right-click `assets/ui_icons/` in Godot's FileSystem dock → **Reimport**
- Assign each icon to its matching `TextureRect` in `src/scenes/ui/GearStatsPanel.tscn`
  via the Godot Inspector (no code changes needed)

## File Checklist

- [ ] `icon_rod.png`
- [ ] `icon_bait.png`
- [ ] `icon_hook.png`
- [ ] `icon_cast_speed.png`
- [ ] `icon_reel_speed.png`
- [ ] `icon_rarity_bonus.png`
- [ ] `icon_bite_speed.png`
- [ ] `icon_durability.png`
- [ ] `icon_coin_bonus.png`
- [ ] `icon_react_window.png`
- [ ] `icon_cast_hint.png`
- [ ] `icon_tier_common.png`
- [ ] `icon_tier_uncommon.png`
- [ ] `icon_tier_rare.png`
- [ ] `icon_tier_legendary.png`
