extends SceneTree

const FAIRNESS := preload("res://src/server/BlackjackFairness.gd")

func _init() -> void:
	call_deferred("_check")

func _check() -> void:
	assert(FAIRNESS.secure_token().length() == 64)
	var server = load("res://src/server/BlackjackServer.gd").new()
	var seed := "00112233445566778899aabbccddeeff"
	var nonce := "shoe-1"
	server._shuffle_shoe(seed, nonce)
	assert(server._shoe.size() == 312)
	assert(server._shoe.duplicate().slice(0, 4).all(func(card): return card is Dictionary))
	var card_counts := {}
	for card: Dictionary in server._shoe:
		var key := "%d:%d" % [card["suit"], card["rank"]]
		card_counts[key] = int(card_counts.get(key, 0)) + 1
	assert(card_counts.size() == 52 and card_counts.values().all(func(count): return count == 6))
	var dealt: Dictionary = server._shoe.pop_back()
	var dealt_key := "%d:%d" % [dealt["suit"], dealt["rank"]]
	assert(server._shoe.size() == 311 and server._shoe.count(dealt) == 5 and card_counts[dealt_key] == 6)
	assert(FAIRNESS.verify_reveal(FAIRNESS.commitment(seed, nonce), seed, nonce, [dealt]))
	assert(not FAIRNESS.verify_reveal(FAIRNESS.commitment(seed, nonce), seed, nonce, [{"suit": 9, "rank": 9}]))
	server._shuffle_shoe(seed, nonce)
	var audited_card: Dictionary = server._draw_card("Tester", "deal")
	assert(server._shoe_audit == [{"actor": "Tester", "action": "deal", "card": audited_card}])
	server.free()
	quit()
