extends SceneTree

func _init() -> void:
	call_deferred("_check")

func _check() -> void:
	var server = load("res://src/server/BlackjackServer.gd").new()
	server._shuffle_shoe()
	assert(server._shoe.size() == 312)
	assert(server._shoe.duplicate().slice(0, 4).all(func(card): return card is Dictionary))
	server.free()
	quit()
