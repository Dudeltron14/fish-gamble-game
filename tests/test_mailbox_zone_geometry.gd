extends SceneTree

func _init() -> void:
	call_deferred("_check")

func _check() -> void:
	var world: Node2D = load("res://src/scenes/world/World.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var player := CharacterBody2D.new()
	player.name = "77"
	player.global_position = world.get_node("Zones/MailboxZone").global_position + Vector2(0, -18)
	world.players.add_child(player)
	assert(world.get_zone_for_peer(77) == "MailboxZone")
	quit()
