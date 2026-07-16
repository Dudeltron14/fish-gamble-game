extends SceneTree

const FishingServerScript := preload("res://src/server/FishingServer.gd")

func _init() -> void:
	var server := FishingServerScript.new()
	assert(server.MAGNET_JUNK.map(func(f: FishData): return f.id) == ["junk_boot", "junk_can", "junk_seaweed"])
	assert(server.MAGNET_TREASURES.map(func(f: FishData): return f.id) == ["legendary_chest", "legendary_key"])
	var chance := server._magnet_treasure_chance(10)
	assert(absf(chance - 0.1294) < 0.0001)
	assert(absf(1.0 - pow(1.0 - chance, 10) - 0.75) < 0.0001)
	server.free()
	quit()
