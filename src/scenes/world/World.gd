extends Node2D

const PLAYER_SCENE  := preload("res://src/scenes/player/Player.tscn")
const FISHING_SCENE := preload("res://src/scenes/fishing/FishingMinigame.tscn")
const SHOP_SCENE    := preload("res://src/scenes/ui/Shop.tscn")
const BJ_SCENE      := preload("res://src/scenes/casino/Blackjack.tscn")
const HUD_SCENE     := preload("res://src/scenes/ui/HUD.tscn")
const DEBUG_SCENE   := preload("res://src/scenes/ui/DebugMenu.tscn")
const STATS_SCENE   := preload("res://src/scenes/ui/GearStatsPanel.tscn")

@onready var players: Node2D       = $Players
@onready var spawn_point: Marker2D = $SpawnPoint

var _local_zone := ""
var _overlay: Node = null
var _overlay_scene: PackedScene = null

func _ready() -> void:
	add_to_group("world")
	for zone in $Zones.get_children():
		if zone is Area2D:
			zone.body_entered.connect(_on_zone_entered.bind(zone.name))
			zone.body_exited.connect(_on_zone_exited.bind(zone.name))
	if not multiplayer.is_server():
		add_child(HUD_SCENE.instantiate())
		add_child(DEBUG_SCENE.instantiate())
		add_child(STATS_SCENE.instantiate())
		NetAPI.fishing_result.connect(_on_fishing_result_received)
		NetAPI.rpc("c2s_world_ready")
	elif GameManager.is_hosting:
		# Host plays in the same instance — spawn host player directly
		add_child(HUD_SCENE.instantiate())
		add_child(DEBUG_SCENE.instantiate())
		add_child(STATS_SCENE.instantiate())
		NetAPI.fishing_result.connect(_on_fishing_result_received)
		var host_session := GameServer.get_session(1)
		if host_session:
			GameManager.equipped_rod_id    = host_session.equipped_rod_id
			GameManager.equipped_bait_id   = host_session.equipped_bait_id
			GameManager.equipped_tackle_id = host_session.equipped_tackle_id
			GameManager.equipped_changed.emit()
			# Sync session inventory directly to client (no DB query needed for host)
			GameManager.set_owned_items(host_session.owned_items.duplicate())
			var tackle := ItemRegistry.get_item(host_session.equipped_tackle_id) as TackleData
			if tackle:
				GameManager.hook_durability = host_session.hook_durability
				GameManager.hook_max_durability = tackle.durability
				GameManager.hook_durability_changed.emit(host_session.hook_durability, tackle.durability)
			spawn_player(1, host_session.username)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _overlay != null:
		return
	match _local_zone:
		"DockZone":   _open_overlay(FISHING_SCENE)
		"ShopZone":   _open_overlay(SHOP_SCENE)
		"CasinoZone": _open_overlay(BJ_SCENE)

func spawn_player(peer_id: int, p_name: String) -> void:
	if not multiplayer.is_server():
		return
	if players.get_node_or_null(str(peer_id)):
		return
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	player.player_name = p_name
	player.position = spawn_point.position
	players.add_child(player, true)

func _despawn_player(peer_id: int) -> void:
	var player := players.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func _get_local_player() -> Node:
	return players.get_node_or_null(str(multiplayer.get_unique_id()))

func _open_overlay(scene: PackedScene) -> void:
	_overlay = scene.instantiate()
	_overlay_scene = scene
	_overlay.completed.connect(_on_overlay_closed)
	add_child(_overlay)
	if scene == FISHING_SCENE:
		var player := _get_local_player()
		if player:
			player.start_fishing()

func _on_overlay_closed() -> void:
	if _overlay_scene == FISHING_SCENE:
		var player := _get_local_player()
		if player:
			player.stop_fishing()
	_overlay = null
	_overlay_scene = null

func _on_fishing_result_received(caught: bool, _fish_id: String, _earned: int, _new_balance: int) -> void:
	if caught:
		var player := _get_local_player()
		if player:
			player.play_hook()

func _on_zone_entered(body: Node2D, zone_name: String) -> void:
	if not body is CharacterBody2D: return
	if body.get_multiplayer_authority() != multiplayer.get_unique_id(): return
	_local_zone = zone_name
	GameManager.set_zone(zone_name)
	NetAPI.rpc("c2s_zone_changed", zone_name)

func _on_zone_exited(body: Node2D, _zone_name: String) -> void:
	if not body is CharacterBody2D: return
	if body.get_multiplayer_authority() != multiplayer.get_unique_id(): return
	_local_zone = ""
	GameManager.set_zone("")
	NetAPI.rpc("c2s_zone_changed", "")
