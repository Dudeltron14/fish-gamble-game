extends SceneTree

func _init() -> void:
	call_deferred("_check")

func _check() -> void:
	var server = load("res://src/server/BlackjackServer.gd").new()
	server._shuffle_shoe()
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
	server.free()
	quit()
