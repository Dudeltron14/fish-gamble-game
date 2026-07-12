# Playtest Feedback

Use this file as the shared intake and triage guide for closed beta feedback. Each actionable feedback item should become its own branch and pull request so contributors can see what is actively being fixed.

## How Playtesters Should Report

Ask playtesters to include this information:

```text
Title:
Severity: Blocker / Bug / Polish / Balance / Idea
Build or date tested:
Platform: Web browser + OS, or Godot client
Account name:
Area: Login / World / Fishing / Shop / Blackjack / Audio / Performance

Steps to reproduce:
Expected result:
Actual result:
How often it happens:
Screenshot, clip, or logs:
Extra notes:
```

Good feedback is specific. "Fishing feels weird" is useful as a first impression, but "after the bobber splashes, the reaction prompt disappears before I can press E in Chrome on Windows" is actionable.

## Triage Flow

1. Confirm whether the report is reproducible.
2. Decide whether it is pre-launch, post-playtest, or not planned.
3. Create one branch for the item.
4. Open one pull request for the fix.
5. Link the feedback report in the PR description.
6. Move any launch-blocking item into `docs/SHIP_CHECKLIST.md`.

Suggested labels:

```text
playtest
bug
blocker
polish
balance
casino
fishing
shop
networking
web
audio
docs
```

## Current Policy

- Closed beta blockers belong in `docs/SHIP_CHECKLIST.md`.
- Economy balance belongs in post-playtest unless it blocks basic progression.
- Stronger fishing anti-cheat is deferred unless playtest feedback shows active abuse or obvious breakage.
- Each feedback fix should stay in a dedicated PR, even if several bugs are discovered during the same session.

## Playtest Intake - 2026-07-11

These notes came from the first broader playtest pass. The items below are grouped into PR-sized work packages so contributors can see what is actively being fixed.

### Active Pre-Launch PR Packages

1. **Shop clarity and gear status** - GitHub issue #1
   - Make the Gear Modifiers tab available from the shop.
   - Make currently equipped items unmistakable in the shop UI.
   - After purchase, remind the player to equip the item.
   - If bait is empty, purchased bait should auto-equip.
   - If hook/tackle is empty, purchased hook/tackle should auto-equip.
   - Show red popup hints when bait runs out or tackle breaks.

2. **Fishing bait and trash tuning** - GitHub issue #2
   - Glow Grub should entirely prevent trash.
   - Glow Grub should have much stronger uncommon/rare odds than Worm.
   - Trash should not be part of the normal Common pool.
   - Trash should scale from cast quality and whether the player has bait equipped.
   - Pearl Clam appears too frequently and needs a weight check.

3. **Chest reward icon** - GitHub issue #3
   - Replace the current chest icon with an updated chest overflowing with gold coins.

4. **Blackjack state and betting bugs** - GitHub issue #4
   - Bet amount should become uneditable once a hand is dealt until the outcome resolves.
   - If the player wins after betting all coins, the previous bet amount should be restored when the balance supports it again.
   - If the bet is too high, show the correct bet/balance error instead of "not at a table".

5. **Blackjack audio and fairness** - GitHub issue #5
   - Add/verify win and loss sounds.
   - Add deck count and shuffling.
   - Use a standard 6-deck shoe.
   - Decide how much "provably fair" transparency is appropriate for this friends-scale beta.

6. **Blackjack polish follow-up** - GitHub issue #6
   - Fix win effects and make emitter placement editable in the Godot scene.
   - Add multiplayer visuals for other players' blackjack matches around the casino.

### Deferred Design / Post-Playtest Ideas

- Prototype momentum-based fishing as a separate system where the player bar has weight, drifts to one side, and gains momentum from opposite input. Fish difficulty should be reduced to account for harder rod control. GitHub issue #7.
- Add a low-priority shovel/worm-digging recovery minigame inspired by Minesweeper: avoid rocks, earn worms if successful. GitHub issue #8.
- Add old-school pipe dock social cosmetics/interactions if the team wants a more adult playtester-requested tone. GitHub issue #9.
- Mock up new fish by identifying empty reward tiers, fish-behavior spaces, and thematic gaps. GitHub issue #10.
- Give Ancient Key a purpose beyond direct money by unlocking a chest/case-opening reward flow. GitHub issue #11.
- Add rich-player skins using the extra character sprite sheets and a possible hidden cosmetic vendor. GitHub issue #12.
- Add a shotgun/shells special fishing upgrade that replaces the rod, skips the minigame, and targets uncommon fish. GitHub issue #13.
- Add limited caught-fish inventory slots and player trading, starting from 5 fish slots. GitHub issue #14.
- Add server-tracked multiplayer blackjack table spectator visuals with distinct table spots. GitHub issue #15.
- Add a tracked 6-deck blackjack shoe with shuffle animation/audio. GitHub issue #16.
- Add an authenticated admin panel for password resets, coin edits, item grants, database visibility, and admin promotion. GitHub issue #17.
- Add a synced day/night cycle with night-only fish in each rarity tier. GitHub issue #18.
- Add a main-menu server status query for online status, connected player count, and ping. GitHub issue #19.
- Reorder Magic Bait in the shop so tiers read more clearly next to Golden Hook and Master Rod. This can be pulled into the shop PR if it is low-risk.
