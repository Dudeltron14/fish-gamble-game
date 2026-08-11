extends Node

var sessions: Dictionary = {}
var _active := false

const STARTER_COINS := 50
const STARTER_ROD_ID := "starter_rod"
const STARTER_BAIT_ID := "worm"
const STARTER_TACKLE_ID := "basic_hook"
const LEADERBOARD_LIMIT := 20
const LEADERBOARD_BROADCAST_INTERVAL := 0.5
const DAY_SECONDS := 15.0 * 60.0
const NIGHT_SECONDS := 5.0 * 60.0
const FISHING_EVENTS: Array[Resource] = [
	preload("res://src/resources/events/fish_school.tres"),
	preload("res://src/resources/events/night_tide.tres"),
	preload("res://src/resources/events/harbor_cleanup.tres"),
]

var _leaderboard_timer: Timer
var _clock_timer: Timer
var _clock_elapsed := 0.0
var _world_phase := "day"
var _world_time_remaining := DAY_SECONDS
var _active_event_index := 0
var _event_time_remaining := 600

func init_server() -> void:
	if _active:
		return
	_active = true
	_leaderboard_timer = Timer.new()
	_leaderboard_timer.one_shot = true
	_leaderboard_timer.wait_time = LEADERBOARD_BROADCAST_INTERVAL
	_leaderboard_timer.timeout.connect(_flush_leaderboard)
	add_child(_leaderboard_timer)
	_clock_timer = Timer.new()
	_clock_timer.wait_time = 1.0
	_clock_timer.timeout.connect(_tick_world_clock)
	add_child(_clock_timer)
	_clock_timer.start()
	for script_path in [
		"res://src/server/AuthServer.gd",
		"res://src/server/FishingServer.gd",
		"res://src/server/ShopServer.gd",
		"res://src/server/TableManager.gd",
		"res://src/server/BlackjackServer.gd",
		"res://src/server/MailboxServer.gd",
		"res://src/server/ProgressionServer.gd",
	]:
		var node: Node = load(script_path).new()
		node.name = script_path.get_file().get_basename().to_pascal_case()
		add_child(node)
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	print("GameServer: initialized")

func get_world_phase() -> String:
	var forced := OS.get_environment("BRINDLE_LOCAL_TIME_PHASE").to_lower()
	return forced if forced in ["day", "night"] else _world_phase

func get_world_time_remaining() -> int:
	return ceili(_world_time_remaining)

func send_world_clock(peer_id: int) -> void:
	NetAPI.rpc_id(peer_id, "notify_world_clock", get_world_phase(), get_world_time_remaining())
	_send_event(peer_id)

func get_active_fishing_event() -> FishingEventData:
	return FISHING_EVENTS[_active_event_index] as FishingEventData

func get_event_time_remaining() -> int:
	return _event_time_remaining

func _send_event(peer_id: int = 0) -> void:
	var event := get_active_fishing_event()
	if peer_id == 0:
		NetAPI.rpc("notify_fishing_event", event.id, event.display_name, event.description, _event_time_remaining)
	else:
		NetAPI.rpc_id(peer_id, "notify_fishing_event", event.id, event.display_name, event.description, _event_time_remaining)

func _tick_world_clock() -> void:
	_clock_elapsed += 1.0
	_world_time_remaining -= 1.0
	_event_time_remaining -= 1
	if _world_time_remaining <= 0.0:
		_world_phase = "night" if _world_phase == "day" else "day"
		_world_time_remaining = NIGHT_SECONDS if _world_phase == "night" else DAY_SECONDS
	if _event_time_remaining <= 0:
		_active_event_index = (_active_event_index + 1) % FISHING_EVENTS.size()
		_event_time_remaining = (get_active_fishing_event() as FishingEventData).duration_seconds
	NetAPI.rpc("notify_world_clock", get_world_phase(), get_world_time_remaining())
	_send_event()

func _on_peer_connected(peer_id: int) -> void:
	sessions[peer_id] = PlayerSession.new(peer_id)
	print("GameServer: peer %d connected (%d total)" % [peer_id, sessions.size()])

func _on_peer_disconnected(peer_id: int) -> void:
	var session: PlayerSession = sessions.get(peer_id, null)
	var blackjack: Node = get_node_or_null("BlackjackServer")
	if blackjack:
		blackjack.handle_player_left(peer_id)
	var tables: Node = get_node_or_null("TableManager")
	if tables:
		tables.remove_peer(peer_id)
	if session:
		var progression := get_node_or_null("ProgressionServer")
		if progression: progression.record_time_played(session, Time.get_ticks_msec() - session.connected_at_ms)
	if sessions.erase(peer_id):
		print("GameServer: peer %d disconnected (%d remaining)" % [peer_id, sessions.size()])
	for world in get_tree().get_nodes_in_group("world"):
		world._despawn_player(peer_id)

func get_starter_items() -> Dictionary:
	var items := {}
	items[STARTER_ROD_ID] = 1
	items[STARTER_BAIT_ID] = get_starter_bait_quantity()
	items[STARTER_TACKLE_ID] = 1
	return items

func get_starter_bait_quantity() -> int:
	var bait := ItemRegistry.get_item(STARTER_BAIT_ID) as BaitData
	return bait.uses_per_stack if bait else 1

func get_starter_hook_durability() -> int:
	var tackle := ItemRegistry.get_item(STARTER_TACKLE_ID) as TackleData
	return tackle.durability if tackle else 0

func get_session(peer_id: int) -> PlayerSession:
	return sessions.get(peer_id, null)

func get_authenticated_session(peer_id: int) -> PlayerSession:
	var s: PlayerSession = sessions.get(peer_id, null)
	return s if (s != null and s.authenticated) else null

func get_authenticated_player_count() -> int:
	var count := 0
	for session in sessions.values():
		if session.authenticated:
			count += 1
	return count

func is_username_authenticated(username: String) -> bool:
	for session: PlayerSession in sessions.values():
		if session.authenticated and session.username == username:
			return true
	return false

func get_leaderboard(metric: String = "coins", page: int = 0, page_size: int = 10) -> Dictionary:
	var auth := get_node_or_null("AuthServer")
	if auth != null and auth._db != null:
		var ranking := "p.coins"
		if metric == "fish": ranking = "COALESCE(s.fish_caught, 0)"
		elif metric == "casino": ranking = "COALESCE(s.casino_won, 0) - COALESCE(s.casino_lost, 0)"
		elif metric == "mail": ranking = "COALESCE(s.mail_coins_sent, 0)"
		auth._db.query("SELECT COUNT(*) AS total FROM players")
		var total := int(auth._db.query_result[0].total) if not auth._db.query_result.is_empty() else 0
		auth._db.query("SELECT p.username, %s AS score FROM players p LEFT JOIN player_career_stats s ON s.player_id = p.id ORDER BY score DESC, p.username ASC LIMIT %d OFFSET %d" % [ranking, page_size, page * page_size])
		return {"entries": auth._db.query_result, "total": total, "metric": metric, "page": page, "page_size": page_size}
	var entries := []
	for session: PlayerSession in sessions.values():
		if session.authenticated:
			entries.append({"username": session.username, "score": session.coins})
	entries.sort_custom(func(a, b): return a.score > b.score)
	return {"entries": entries.slice(page * page_size, (page + 1) * page_size), "total": entries.size(), "metric": metric, "page": page, "page_size": page_size}

func broadcast_leaderboard() -> void:
	if _leaderboard_timer.is_stopped():
		_leaderboard_timer.start()

func _flush_leaderboard() -> void:
	NetAPI.rpc("notify_leaderboard", get_leaderboard())
