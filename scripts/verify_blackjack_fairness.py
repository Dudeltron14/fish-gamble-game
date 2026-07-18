#!/usr/bin/env python3
"""Verify a JSON reveal copied from Brindle's completed blackjack shoe."""

import argparse
import hashlib
import json
import sys

VERSION = "fish-gamble-blackjack-v1"


def digest(text):
    return hashlib.sha256(text.encode()).digest()


def commitment(seed, nonce):
    return digest(f"{VERSION}|{seed}|{nonce}").hex()


def make_shoe(seed, nonce):
    cards = [{"suit": suit, "rank": rank} for _ in range(6) for suit in range(4) for rank in range(13)]
    for index in range(len(cards) - 1, 0, -1):
        swap = int.from_bytes(digest(f"{seed}|{nonce}|{index}")[:4], "big") % (index + 1)
        cards[index], cards[swap] = cards[swap], cards[index]
    return cards


def verify(reveal, seen_commitment=""):
    required = ("commitment", "seed", "nonce", "dealt_cards")
    if not all(key in reveal for key in required):
        return False, "missing required reveal fields"
    actual = commitment(reveal["seed"], reveal["nonce"])
    if actual != reveal["commitment"]:
        return False, "seed and nonce do not reproduce the reveal commitment"
    if seen_commitment and seen_commitment != actual:
        return False, "reveal commitment differs from the commitment observed before play"
    shoe = make_shoe(reveal["seed"], reveal["nonce"])
    dealt = reveal["dealt_cards"]
    if len(dealt) > len(shoe):
        return False, "more than 312 cards were logged"
    for index, card in enumerate(dealt, 1):
        if card != shoe.pop():
            return False, f"card {index} does not match the committed shoe"
    audit = reveal.get("audit_log", [])
    if audit and (len(audit) != len(dealt) or any(entry.get("card") != card for entry, card in zip(audit, dealt))):
        return False, "audit log does not match the dealt-card sequence"
    return True, f"{len(dealt)} dealt cards match the precommitted 312-card shoe"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reveal", help="JSON file copied with Copy Last Fairness Reveal")
    parser.add_argument("--commitment", help="full commitment copied before the shoe was dealt")
    args = parser.parse_args()
    with open(args.reveal, encoding="utf-8") as file:
        reveal = json.load(file)
    valid, message = verify(reveal, args.commitment)
    print(("VERIFIED: " if valid else "FAILED: ") + message)
    return 0 if valid else 1


if __name__ == "__main__":
    sys.exit(main())
