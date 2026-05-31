# Sound Effects — Generation Spec

## Style Reference

The game is a **casual pixel art fishing and gambling game** — warm, friendly, and satisfying.
Sound effects should feel like a quality indie game (think Stardew Valley, Animal Crossing, or
Webfishing). Clean, punchy, and pleasant. Nothing jarring or overly dramatic.

The world is a sunny island with a dock, a fish shop, and a small casino.
Players fish, shop, and gamble with friends in a laid-back atmosphere.

---

## Technical Requirements (apply to ALL sounds)

| Property | Value |
|---|---|
| Format | **OGG Vorbis** for longer sounds; **WAV** acceptable for very short clicks |
| Sample rate | 44100 Hz |
| Channels | Stereo or Mono (mono preferred for short SFX) |
| Bit depth | 16-bit |
| Normalisation | Peak at −3 dBFS max |
| Background | Silence only — no room tone, no hiss |
| Length note | Shorter is better for UI/interaction sounds — aim for punchy, not drawn-out |

---

## Drop Location

Save all files to: **`assets/sfx/`**

---

## Fishing Minigame

---

### `sfx_cast.wav`
**Trigger:** Player releases E to cast — the power bar locks in and the cast begins.
**Character:** A short, satisfying *whoosh* or *swish* — like a fishing rod cutting through air.
Think of the sound a whip or thin rod makes when swung. Light and airy, not heavy.
**Duration:** 0.3–0.5s
**Tone:** Bright, mid-high frequency swoosh. Light reverb tail okay.

---

### `sfx_bite.wav`
**Trigger:** `!! BITE !!` alert appears — the fish has taken the lure.
**Character:** A quick, attention-grabbing *ping* or *ding* — like a small bell or notification chime.
Should feel urgent but not alarming. The player needs to react fast.
**Duration:** 0.2–0.4s
**Tone:** Bright, clear bell hit. Short attack, quick decay.

---

### `sfx_reel_tick.wav`
**Trigger:** Short click played repeatedly while the cursor overlaps the catch zone (in zone).
**Character:** A soft, rhythmic *tick* or *click* — like a fishing reel pawl clicking.
Should be subtle enough to loop pleasantly without becoming annoying.
**Duration:** 0.05–0.1s (very short — will be played rapidly in sequence)
**Tone:** Dry mechanical click, low-mid frequency. No reverb.

---

### `sfx_catch.wav`
**Trigger:** Fish successfully caught — catch meter reaches 100%.
**Character:** A cheerful success sound — short ascending chime or bright fanfare.
Satisfying and rewarding. Like a "level up" or treasure chest jingle from a JRPG, but smaller.
**Duration:** 0.6–1.2s
**Tone:** Bright, warm, major key. Light orchestral or chiptune style.

---

### `sfx_miss.wav`
**Trigger:** Fish escapes — escape timer hits 0 or react window missed.
**Character:** A soft, brief *whomp* or descending tone. Disappointed but not punishing.
Think of the "bonk" sound in Animal Crossing or a gentle failure sting.
**Duration:** 0.4–0.7s
**Tone:** Descending, slightly muffled. Not harsh. Rueful, not brutal.

---

### `sfx_hook_break.wav`
**Trigger:** Hook durability reaches 0 and breaks.
**Character:** A small *snap* or *crack* — like a thin metal hook breaking under tension.
Slightly satisfying (like snapping a twig) but clearly communicates loss.
**Duration:** 0.2–0.3s
**Tone:** Short sharp crack, dry, mid-frequency.

---

### `sfx_bait_empty.wav`
**Trigger:** Last bait is consumed — the bait slot clears.
**Character:** A soft *pop* or hollow *thud* — like an empty container being set down.
Subtle notification that something ran out.
**Duration:** 0.15–0.25s
**Tone:** Hollow, slightly muffled pop. Low-mid frequency.

---

## Shop

---

### `sfx_buy.wav`
**Trigger:** Item successfully purchased from the shop.
**Character:** A satisfying *ka-ching* or coin-drop sound. Short and rewarding.
**Duration:** 0.3–0.5s
**Tone:** Bright coin jingle, mid-high frequency. Classic cash register feel.

---

### `sfx_equip.wav`
**Trigger:** Item successfully equipped.
**Character:** A light *whoosh* + soft *click* — like something locking into place.
Confirms an action was taken. Short and clean.
**Duration:** 0.2–0.4s
**Tone:** Brief swish into a satisfying click. Warm, not metallic.

---

### `sfx_not_enough_coins.wav`
**Trigger:** Purchase attempt fails due to insufficient coins.
**Character:** A gentle *buzz* or *bwonk* — the classic "can't do that" sound.
Short, clear, not humiliating.
**Duration:** 0.2–0.3s
**Tone:** Low buzz or muffled thunk. Minor / descending.

---

## General UI

---

### `sfx_menu_open.wav`
**Trigger:** Shop, fishing minigame, or blackjack overlay opens.
**Character:** A light *whoosh* or *slide* — the UI panel appearing.
**Duration:** 0.15–0.3s
**Tone:** Airy upward swoosh. Clean.

---

### `sfx_menu_close.wav`
**Trigger:** Any overlay closes.
**Character:** Inverse of menu_open — a downward whoosh or soft *thud*.
**Duration:** 0.15–0.3s
**Tone:** Downward sweep or soft close. Paired with menu_open.

---

### `sfx_coins.wav`
**Trigger:** Coins are added to the player's balance (fish sold, blackjack win, etc.).
**Character:** A small cascade of coin sounds — 2–4 quick coin *clinks*.
**Duration:** 0.3–0.6s
**Tone:** Bright metallic clinks, slightly randomised pitch feel. Joyful.

---

## Blackjack

---

### `sfx_card_deal.wav`
**Trigger:** Each card is dealt (plays once per card with staggered timing).
**Character:** A crisp card *flick* or *slap* — like a playing card being laid on a table.
Should feel satisfying to hear multiple times in quick succession.
**Duration:** 0.1–0.2s
**Tone:** Dry paper/card sound. Short attack, quick decay. No reverb.

---

### `sfx_blackjack_win.wav`
**Trigger:** Player wins a blackjack round.
**Character:** A short celebratory sting — upbeat and victorious but brief.
Slightly more dramatic than sfx_catch since blackjack wins are rarer.
**Duration:** 0.8–1.5s
**Tone:** Bright ascending phrase. Brass or chiptune fanfare style.

---

### `sfx_blackjack_lose.wav`
**Trigger:** Player loses a blackjack round (bust or dealer wins).
**Character:** A short descending sting — disappointed but not crushing. Wah-wah optional.
**Duration:** 0.5–1.0s
**Tone:** Descending phrase. Trombone "wah-wah" or minor descend. Gentle.

---

### `sfx_blackjack_push.wav`
**Trigger:** Push (tie) result in blackjack.
**Character:** A neutral, slightly unresolved short tone. Neither win nor loss.
**Duration:** 0.3–0.5s
**Tone:** Flat or slightly ambiguous chord. Dry.

---

## Delivery Checklist

- [ ] `sfx_cast.wav`
- [ ] `sfx_bite.wav`
- [ ] `sfx_reel_tick.wav`
- [ ] `sfx_catch.wav`
- [ ] `sfx_miss.wav`
- [ ] `sfx_hook_break.wav`
- [ ] `sfx_bait_empty.wav`
- [ ] `sfx_buy.wav`
- [ ] `sfx_equip.wav`
- [ ] `sfx_not_enough_coins.wav`
- [ ] `sfx_menu_open.wav`
- [ ] `sfx_menu_close.wav`
- [ ] `sfx_coins.wav`
- [ ] `sfx_card_deal.wav`
- [ ] `sfx_blackjack_win.wav`
- [ ] `sfx_blackjack_lose.wav`
- [ ] `sfx_blackjack_push.wav`

**Total: 17 sound effects**

Drop all files into: `assets/sfx/`
After adding, right-click `assets/sfx/` in Godot's FileSystem dock → **Reimport**.
