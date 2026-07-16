# Blackjack Fairness Guide

Every six-deck blackjack shoe is committed before its first card is dealt. This lets a player confirm that the revealed cards came from one predetermined order rather than a shoe changed mid-game.

## What players see

While blackjack is open, the subtle bottom-right overlay shows the active **Fair shoe** commitment. It is a full SHA-256 hash, split over four lines for readability.

When the shoe is replaced at the three-deck cut card, the previous shoe's seed, nonce, and ordered dealt-card log are revealed. **Copy Last Fairness Reveal** becomes available; it copies that material as JSON.

## Quick check

1. Open Blackjack and note that a `Fair shoe` commitment appears before dealing.
2. Play until the shoe is replaced, then click **Copy Last Fairness Reveal**.
3. Paste the result into a text editor. It includes `commitment`, `seed`, `nonce`, `dealt_cards`, and the game's local `verified` result.
4. A value of `verified: true` means the client reproduced the committed shoe and every logged dealt card matched its predetermined order.

## Independent verification

The game performs this check locally, but anyone can repeat it independently. Save the copied JSON as `reveal.json`, then run this Python 3 script in the same directory:

```python
import hashlib
import json

VERSION = "fish-gamble-blackjack-v1"

def sha256(text):
    return hashlib.sha256(text.encode()).digest()

def commitment(seed, nonce):
    return sha256(f"{VERSION}|{seed}|{nonce}").hex()

def make_shoe(seed, nonce):
    cards = [
        {"suit": suit, "rank": rank}
        for _deck in range(6)
        for suit in range(4)
        for rank in range(13)
    ]
    for i in range(len(cards) - 1, 0, -1):
        index = int.from_bytes(sha256(f"{seed}|{nonce}|{i}")[:4], "big") % (i + 1)
        cards[i], cards[index] = cards[index], cards[i]
    return cards

reveal = json.load(open("reveal.json", encoding="utf-8"))
shoe = make_shoe(reveal["seed"], reveal["nonce"])
valid_commitment = commitment(reveal["seed"], reveal["nonce"]) == reveal["commitment"]
valid_log = all(card == shoe.pop() for card in reveal["dealt_cards"])
print("VERIFIED" if valid_commitment and valid_log else "FAILED")
```

`VERIFIED` confirms both of these facts:

- The revealed seed and nonce produce the commitment shown before the shoe was dealt.
- Every logged card is in the exact order generated from that committed seed and nonce.

## Technical details

- A cryptographically secure 32-byte secret seed and 16-byte shoe nonce are generated for every shoe.
- The server publishes `SHA-256("fish-gamble-blackjack-v1|seed|nonce")` before dealing.
- The canonical 312-card shoe (six copies of every standard card) is shuffled deterministically with SHA-256-derived Fisher–Yates indices.
- The server records every card draw and persists the commitment, seed, nonce, log, creation time, and reveal time in SQLite.
- The active seed remains private until the shoe is replaced, so players cannot predict upcoming cards.

## Scope and limitation

This protocol proves that the server did not alter a shoe after publishing its commitment. It does not yet incorporate player-provided seeds, so it does not independently prove that the server could not choose a particular seed before committing. A future hardening step can combine sorted client seeds with the server seed before the commitment is made.

Fairness verification is separate from the normal blackjack rules: it verifies the card order, not whether a player chose an optimal action or whether a payout rule is desirable.
