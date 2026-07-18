extends Node2D

const PLAYER_SCENE  := preload("res://src/scenes/player/Player.tscn")
const FISHING_SCENE := preload("res://src/scenes/fishing/FishingMinigame.tscn")
const SHOP_SCENE    := preload("res://src/scenes/ui/Shop.tscn")
const BJ_SCENE      := preload("res://src/scenes/casino/Blackjack.tscn")
const HUD_SCENE     := preload("res://src/scenes/ui/HUD.tscn")
const STATS_SCENE   := preload("res://src/scenes/ui/GearStatsPanel.tscn")
const LEADERBOARD_SCENE := preload("res://src/scenes/ui/LeaderboardPanel.tscn")

@onready var players: Node2D       = $Players
@onready var spawn_point: Marker2D = $SpawnPoint

var _local_zone := ""
var _overlay: Node = null
var _overlay_scene: PackedScene = null
var _server_update_dialog: AcceptDialog = null
var _stats_panel: CanvasLayer = null
var _leaderboard_panel: CanvasLayer = null
var _overlay_hides_player := false
var _overlay_entry_position := Vector2.ZERO
var _intentional_disconnect := false
var _stats_panel_was_visible := true
var _leaderboard_panel_was_visible := true

func _ready() -> void:
	add_to_group("world")
	AudioManager.set_music_context("world")
	if not NetworkManager.server_disconnected.is_connected(_on_server_disconnected):
		NetworkManager.server_disconnected.connect(_on_server_disconnected)
	for zone in $Zones.get_children():
		if zone is Area2D:
			zone.collision_mask = 4
			zone.body_entered.connect(_on_zone_entered.bind(zone.name))
			zone.body_exited.connect(_on_zone_exited.bind(zone.name))
	if not multiplayer.is_server():
		add_child(HUD_SCENE.instantiate())
		_stats_panel = STATS_SCENE.instantiate()
		add_child(_stats_panel)
		_leaderboard_panel = LEADERBOARD_SCENE.instantiate()
		add_child(_leaderboard_panel)
		NetAPI.fishing_result.connect(_on_fishing_result_received)
		NetAPI.bait_empty.connect(func(): AudioManager.sfx("sfx_bait_empty"))
		NetAPI.hook_broken.connect(func(): AudioManager.sfx("sfx_hook_break"))
		_notify_world_ready()
	elif GameManager.is_hosting:
		NetAPI.bait_empty.connect(func(): AudioManager.sfx("sfx_bait_empty"))
		NetAPI.hook_broken.connect(func(): AudioManager.sfx("sfx_hook_break"))
		# Host plays in the same instance — spawn host player directly
		add_child(HUD_SCENE.instantiate())
		_stats_panel = STATS_SCENE.instantiate()
		add_child(_stats_panel)
		_leaderboard_panel = LEADERBOARD_SCENE.instantiate()
		add_child(_leaderboard_panel)
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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _can_open_settings():
		ClientSettings.open(self)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _can_open_settings():
			ClientSettings.open(self)
			get_viewport().set_input_as_handled()
		return
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
		push_warning("World: spawn ignored; peer %d already exists" % peer_id)
		_sync_players_to_peer(peer_id)
		return
	push_warning("World: spawning player peer=%d name=%s" % [peer_id, p_name])
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	player.player_name = p_name
	player.set_meta("player_name", p_name)
	player.position = spawn_point.position
	players.add_child(player)
	_broadcast_player_spawn(player, p_name)
	_sync_players_to_peer(peer_id)

func ensure_player(peer_id: int, p_name: String, spawn_position: Vector2) -> void:
	var player := players.get_node_or_null(str(peer_id)) as CharacterBody2D
	if player == null:
		player = PLAYER_SCENE.instantiate()
		player.name = str(peer_id)
		player.position = spawn_position
		players.add_child(player)
	player.set_multiplayer_authority(peer_id)
	player.player_name = p_name
	player.set_meta("player_name", p_name)
	if player.position == Vector2.ZERO:
		player.position = spawn_position
	if player.has_method("configure_spawned_player"):
		player.configure_spawned_player(spawn_position)

func apply_authoritative_player_input(peer_id: int, input_dir: Vector2, animation: String, flip_h: bool, hidden: bool, bobber_cast_quality: float = -1.0) -> void:
	var player := players.get_node_or_null(str(peer_id))
	if player == null:
		return
	if player.has_method("apply_server_input"):
		player.apply_server_input(input_dir, animation, flip_h, hidden, bobber_cast_quality)

func apply_remote_player_state(peer_id: int, pos: Vector2, animation: String, flip_h: bool, hidden: bool, bobber_cast_quality: float = -1.0) -> void:
	var player := players.get_node_or_null(str(peer_id))
	if player == null:
		return
	if player.has_method("apply_remote_state"):
		player.apply_remote_state(pos, animation, flip_h, hidden, bobber_cast_quality)

func show_player_catch(peer_id: int, fish_id: String) -> void:
	var player := players.get_node_or_null(str(peer_id))
	if player and player.has_method("show_catch"):
		player.show_catch(fish_id)

func despawn_remote_player(peer_id: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting:
		return
	_remove_player_node(peer_id)

func _broadcast_player_spawn(player: CharacterBody2D, p_name: String = "") -> void:
	NetAPI.rpc("notify_world_player_spawned", player.name.to_int(), _player_display_name(player, p_name), player.position)

func _sync_players_to_peer(peer_id: int) -> void:
	for child in players.get_children():
		var player := child as CharacterBody2D
		if player == null:
			continue
		NetAPI.rpc_id(peer_id, "notify_world_player_spawned", player.name.to_int(), _player_display_name(player), player.position)
	call_deferred("_sync_players_to_peer_deferred", peer_id)

func _sync_players_to_peer_deferred(peer_id: int) -> void:
	await get_tree().process_frame
	for child in players.get_children():
		var player := child as CharacterBody2D
		if player == null:
			continue
		NetAPI.rpc_id(peer_id, "notify_world_player_spawned", player.name.to_int(), _player_display_name(player), player.position)

func _player_display_name(player: CharacterBody2D, fallback: String = "") -> String:
	if not fallback.is_empty():
		return fallback
	var meta_name := str(player.get_meta("player_name", ""))
	if not meta_name.is_empty():
		return meta_name
	var property_name := str(player.get("player_name"))
	if not property_name.is_empty() and property_name != "<null>":
		return property_name
	return "Player %s" % player.name

func _notify_world_ready() -> void:
	await get_tree().process_frame
	for attempt in 10:
		if _get_local_player() != null:
			return
		print("World: sending c2s_world_ready to server attempt=%d" % [attempt + 1])
		NetAPI.rpc_id(1, "c2s_world_ready")
		await get_tree().create_timer(0.5).timeout

func _despawn_player(peer_id: int) -> void:
	_remove_player_node(peer_id)
	if multiplayer.is_server():
		NetAPI.rpc("notify_world_player_despawned", peer_id)

func _remove_player_node(peer_id: int) -> void:
	var player := players.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func get_zone_for_peer(peer_id: int) -> String:
	var player := players.get_node_or_null(str(peer_id))
	if player == null:
		return ""
	for zone in $Zones.get_children():
		if zone is Area2D and _zone_contains_player(zone, player):
			return zone.name
	return ""

func _zone_contains_player(zone: Area2D, player: Node2D) -> bool:
	if _zone_contains_point(zone, player.global_position):
		return true
	for zone_shape_node in zone.get_children():
		var zone_shape := zone_shape_node as CollisionShape2D
		if zone_shape == null or zone_shape.disabled:
			continue
		var zone_rect := zone_shape.shape as RectangleShape2D
		if zone_rect == null:
			continue
		var zone_bounds := _rect_shape_global_bounds(zone_shape, zone_rect)
		for player_shape_node in player.get_children():
			var player_shape := player_shape_node as CollisionShape2D
			if player_shape == null or player_shape.disabled:
				continue
			var player_rect := player_shape.shape as RectangleShape2D
			if player_rect:
				var player_bounds := _rect_shape_global_bounds(player_shape, player_rect)
				if zone_bounds.intersects(player_bounds, true):
					return true
			elif zone_bounds.has_point(player_shape.global_position):
				return true
	return false

func _zone_contains_point(zone: Area2D, point: Vector2) -> bool:
	for child in zone.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null or shape_node.disabled:
			continue
		var rect := shape_node.shape as RectangleShape2D
		if rect == null:
			continue
		var local_point := shape_node.global_transform.affine_inverse() * point
		if absf(local_point.x) <= rect.size.x * 0.5 and absf(local_point.y) <= rect.size.y * 0.5:
			return true
	return false

func _rect_shape_global_bounds(shape_node: CollisionShape2D, rect: RectangleShape2D) -> Rect2:
	var half_size := rect.size * 0.5
	var corners := [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	]
	var first_point: Vector2 = shape_node.global_transform * corners[0]
	var min_point := first_point
	var max_point := first_point
	for i in range(1, corners.size()):
		var point: Vector2 = shape_node.global_transform * corners[i]
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)

func _get_local_player() -> Node:
	return players.get_node_or_null(str(multiplayer.get_unique_id()))

func _open_overlay(scene: PackedScene) -> void:
	_overlay = scene.instantiate()
	_overlay_scene = scene
	_overlay.completed.connect(_on_overlay_closed)
	add_child(_overlay)
	AudioManager.sfx("sfx_menu_open")
	_overlay_hides_player = scene == SHOP_SCENE or scene == BJ_SCENE
	if scene == SHOP_SCENE and _stats_panel != null and is_instance_valid(_stats_panel):
		_stats_panel_was_visible = _stats_panel.visible
		_stats_panel.visible = false
	if (scene == SHOP_SCENE or scene == BJ_SCENE) and _leaderboard_panel != null and is_instance_valid(_leaderboard_panel):
		_leaderboard_panel_was_visible = _leaderboard_panel.visible
		_leaderboard_panel.visible = false
	var player := _get_local_player()
	if player:
		_overlay_entry_position = player.global_position
	_set_local_player_menu_hidden(_overlay_hides_player)
	if scene == FISHING_SCENE:
		if player:
			player.start_fishing()

func _on_overlay_closed() -> void:
	AudioManager.sfx("sfx_menu_close")
	var player := _get_local_player()
	if _overlay_hides_player and player and player.has_method("resume_from_menu_at"):
		player.resume_from_menu_at(_overlay_entry_position)
	else:
		_set_local_player_menu_hidden(false)
	if _overlay_scene == FISHING_SCENE:
		if player:
			player.stop_fishing()
		GameManager.fishing_result_completed.emit()
	if _overlay_scene == SHOP_SCENE and _stats_panel != null and is_instance_valid(_stats_panel):
		_stats_panel.visible = _stats_panel_was_visible
	if (_overlay_scene == SHOP_SCENE or _overlay_scene == BJ_SCENE) and _leaderboard_panel != null and is_instance_valid(_leaderboard_panel):
		_leaderboard_panel.visible = _leaderboard_panel_was_visible
	_overlay = null
	_overlay_scene = null
	_overlay_hides_player = false

func _can_open_settings() -> bool:
	return _overlay == null \
		and not ClientSettings.is_open() \
		and not _is_leaderboard_panel_open()

func _is_leaderboard_panel_open() -> bool:
	return _leaderboard_panel != null \
		and is_instance_valid(_leaderboard_panel) \
		and _leaderboard_panel.has_method("is_expanded") \
		and _leaderboard_panel.is_expanded()

func disconnect_to_login() -> void:
	_intentional_disconnect = true
	NetworkManager.disconnect_from_server()
	_reset_session_and_go_to_login()

func _on_server_disconnected() -> void:
	if _intentional_disconnect or multiplayer.is_server():
		return
	if _server_update_dialog != null and is_instance_valid(_server_update_dialog):
		_server_update_dialog.popup_centered()
		return
	_server_update_dialog = AcceptDialog.new()
	_server_update_dialog.title = "Server Update"
	_server_update_dialog.dialog_text = "The server closed for a quick update. Please reconnect in a moment."
	_server_update_dialog.ok_button_text = "Back to Login"
	_server_update_dialog.confirmed.connect(_reset_session_and_go_to_login)
	_server_update_dialog.close_requested.connect(_reset_session_and_go_to_login)
	_server_update_dialog.tree_exited.connect(func(): _server_update_dialog = null)
	add_child(_server_update_dialog)
	_server_update_dialog.popup_centered()

func _reset_session_and_go_to_login() -> void:
	GameManager.is_hosting = false
	GameManager.current_player_name = ""
	GameManager.set_coins(0)
	GameManager.set_zone("")
	GameManager.set_owned_items({})
	GameManager.equipped_rod_id = ""
	GameManager.equipped_bait_id = ""
	GameManager.equipped_tackle_id = ""
	GameManager.equipped_changed.emit()
	GameManager.hook_durability = 0
	GameManager.hook_max_durability = 0
	GameManager.hook_durability_changed.emit(0, 0)
	GameManager.go_to_scene("res://src/scenes/ui/LoginScreen.tscn")

func _on_fishing_result_received(caught: bool, _fish_id: String, _earned: int, _new_balance: int) -> void:
	if caught:
		var player := _get_local_player()
		if player:
			player.play_hook()

func _set_local_player_menu_hidden(hidden: bool) -> void:
	var player := _get_local_player()
	if player and player.has_method("set_menu_hidden"):
		player.set_menu_hidden(hidden)

func set_local_player_cast_quality(cast_quality: float) -> void:
	var player := _get_local_player()
	if player and player.has_method("set_cast_quality"):
		player.set_cast_quality(cast_quality)

func _on_zone_entered(body: Node2D, zone_name: String) -> void:
	if not body is CharacterBody2D: return
	if body.get_multiplayer_authority() != multiplayer.get_unique_id(): return
	_local_zone = zone_name
	GameManager.set_zone(zone_name)
	NetAPI.rpc_id(1, "c2s_zone_changed", zone_name)

func _on_zone_exited(body: Node2D, _zone_name: String) -> void:
	if not body is CharacterBody2D: return
	if body.get_multiplayer_authority() != multiplayer.get_unique_id(): return
	_local_zone = ""
	GameManager.set_zone("")
	NetAPI.rpc_id(1, "c2s_zone_changed", "")
