extends SceneTree

const FAIRNESS := preload("res://src/server/BlackjackFairness.gd")

func _init() -> void:
	call_deferred("_check")

func _check() -> void:
	assert(FAIRNESS.secure_token().length() == 64)
	var manager: Node = load("res://src/server/TableManager.gd").new()
	manager.register_table("test_blackjack", "blackjack", "CasinoZone", 2)
	assert(manager.join("test_blackjack", 11) == 0)
	assert(manager.join("test_blackjack", 12) == 1)
	assert(manager.join("test_blackjack", 13) == -1)
	assert(manager.watch("test_blackjack", 13) and manager.recipients("test_blackjack") == [11, 12, 13])
	manager.set_phase("test_blackjack", "player_turns")
	manager.set_active_seat("test_blackjack", 1)
	manager.set_seat_public("test_blackjack", 11, {"bet": 10})
	assert(manager.is_seated("test_blackjack", 11) and manager.occupied_peers("test_blackjack") == [11, 12])
	assert(manager.leave("test_blackjack", 12) and not manager.is_seated("test_blackjack", 12))
	assert(manager.remove_peer(13) == ["test_blackjack"] and manager.recipients("test_blackjack") == [11])
	manager.register_table("test_poker", "poker", "CasinoZone", 3)
	assert(manager.join("test_poker", 21) == 0 and manager.is_seated("test_poker", 21))
	var poker_turns: Array[int] = [21]
	manager.set_turn_order("test_poker", poker_turns)
	assert(manager.next_turn_peer("test_poker") == 21 and manager.current_turn_peer("test_poker") == 21)
	assert(manager.next_turn_peer("test_poker") == 0)
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
	assert(server._dealer_peeks_blackjack([{"suit": 0, "rank": 0}, {"suit": 1, "rank": 12}]))
	assert(not server._dealer_peeks_blackjack([{"suit": 0, "rank": 0}, {"suit": 1, "rank": 8}]))
	server._next_hand_id = 9
	server._shuffle_shoe(seed, nonce)
	assert(server._next_hand_id == 1)
	server.free()
	manager.free()
	quit()
