extends SceneTree

const FishingServerScript := preload("res://src/server/FishingServer.gd")
const PlayerSessionScript := preload("res://src/server/PlayerSession.gd")

func _init() -> void:
	var server := FishingServerScript.new()
	assert(server.MAGNET_JUNK.map(func(f: FishData): return f.id) == ["junk_boot", "junk_can", "junk_seaweed"])
	assert(server.MAGNET_TREASURES.map(func(f: FishData): return f.id) == ["legendary_chest", "legendary_key"])
	var chance := server._magnet_treasure_chance(10)
	assert(is_equal_approx(chance, 0.55))
	server.free()
	var session := PlayerSessionScript.new(1)
	session.equipped_bait_id = "glow_grub"
	session.equipped_tackle_id = "treasure_magnet"
	assert(session.enforce_equipment_rules() and session.equipped_bait_id.is_empty())
	session.select_tackle("basic_hook", 10)
	session.set_current_hook_durability(1)
	session.select_tackle("golden_hook", 20)
	assert(session.hook_durability == 20)
	session.select_tackle("basic_hook", 10)
	assert(session.hook_durability == 1)
	quit()
