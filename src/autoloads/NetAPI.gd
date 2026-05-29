extends Node

signal login_result(ok: bool, reason: String, coins: int)
signal register_result(ok: bool, reason: String)

# ── Client → Server ──────────────────────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func request_login(username: String, pw_hash: String) -> void:
	if not multiplayer.is_server():
		return
	var auth := _get_auth()
	if auth:
		auth.handle_login(multiplayer.get_remote_sender_id(), username, pw_hash)

@rpc("any_peer", "call_remote", "reliable")
func request_register(username: String, pw_hash: String) -> void:
	if not multiplayer.is_server():
		return
	var auth := _get_auth()
	if auth:
		auth.handle_register(multiplayer.get_remote_sender_id(), username, pw_hash)

@rpc("any_peer", "call_remote", "reliable")
func c2s_world_ready() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null:
		return
	for world in get_tree().get_nodes_in_group("world"):
		world.spawn_player(peer_id, session.username)

@rpc("any_peer", "call_remote", "reliable")
func c2s_zone_changed(zone_name: String) -> void:
	if not multiplayer.is_server():
		return
	var session := GameServer.get_authenticated_session(multiplayer.get_remote_sender_id())
	if session:
		session.current_zone = zone_name

# ── Server → Client ──────────────────────────────────────────────────────────

@rpc("authority", "call_remote", "reliable")
func notify_login(ok: bool, reason: String, coins: int) -> void:
	login_result.emit(ok, reason, coins)

@rpc("authority", "call_remote", "reliable")
func notify_register(ok: bool, reason: String) -> void:
	register_result.emit(ok, reason)

# ── Helpers ──────────────────────────────────────────────────────────────────

func _get_auth() -> Node:
	return GameServer.get_node_or_null("AuthServer")
