extends SceneTree

const FishingServerScript := preload("res://src/server/FishingServer.gd")

func _init() -> void:
	var server := FishingServerScript.new()
	assert(server.MAGNET_JUNK.map(func(f: FishData): return f.id) == ["junk_boot", "junk_can", "junk_seaweed"])
	assert(server.MAGNET_TREASURES.map(func(f: FishData): return f.id) == ["legendary_chest", "legendary_key"])
	assert(absf(server._magnet_treasure_chance(10) - 0.0768) < 0.0001)
	server.free()
	quit()
