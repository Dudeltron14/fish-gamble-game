class_name BlackjackFairness extends RefCounted

const VERSION := "fish-gamble-blackjack-v1"

static func secure_token(byte_count: int = 32) -> String:
	return Crypto.new().generate_random_bytes(byte_count).hex_encode()

static func commitment(seed: String, nonce: String) -> String:
	return _digest("%s|%s|%s" % [VERSION, seed, nonce]).hex_encode()

static func make_shoe(seed: String, nonce: String) -> Array:
	var shoe: Array = []
	for _deck_index in range(6):
		for suit in range(4):
			for rank in range(13):
				shoe.append({"suit": suit, "rank": rank})
	for i in range(shoe.size() - 1, 0, -1):
		var bytes := _digest("%s|%s|%d" % [seed, nonce, i])
		var value := 0
		for byte_index in range(4):
			value = (value << 8) | int(bytes[byte_index])
		var swap_index := value % (i + 1)
		var card = shoe[i]
		shoe[i] = shoe[swap_index]
		shoe[swap_index] = card
	return shoe

static func verify_reveal(commit: String, seed: String, nonce: String, dealt_cards: Array) -> bool:
	if commitment(seed, nonce) != commit or dealt_cards.size() > 312:
		return false
	var expected := make_shoe(seed, nonce)
	for dealt_card in dealt_cards:
		var expected_card: Dictionary = expected.pop_back()
		if not dealt_card is Dictionary or dealt_card.get("suit") != expected_card.suit or dealt_card.get("rank") != expected_card.rank:
			return false
	return true

static func _digest(text: String) -> PackedByteArray:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish()
