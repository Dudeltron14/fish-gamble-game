extends SceneTree

const FishingServerScript := preload("res://src/server/FishingServer.gd")
const PlayerSessionScript := preload("res://src/server/PlayerSession.gd")
const ShopServerScript := preload("res://src/server/ShopServer.gd")

func _init() -> void:
	var server := FishingServerScript.new()
	assert(server.MAGNET_JUNK.map(func(f: FishData): return f.id) == ["junk_boot", "junk_can", "junk_seaweed"])
	assert(server.MAGNET_TREASURES.map(func(f: FishData): return f.id) == ["legendary_chest", "legendary_key"])
	var chance := server._magnet_treasure_chance(10)
	assert(absf(chance - 0.1728) < 0.0001)
	assert(absf(1.0 - pow(1.0 - chance, 10) - 0.85) < 0.0001)
	server.free()
	var session := PlayerSessionScript.new(1)
	session.equipped_bait_id = "glow_grub"
	session.equipped_tackle_id = "treasure_magnet"
	assert(session.enforce_equipment_rules() and session.equipped_bait_id.is_empty())
	assert(ShopServerScript._durability_after_tackle_equip(1, true, 10) == 1)
	assert(ShopServerScript._durability_after_tackle_equip(0, false, 10) == 10)
	quit()
