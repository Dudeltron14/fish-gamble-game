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

# ── Server → Client ──────────────────────────────────────────────────────────

@rpc("authority", "call_remote", "reliable")
func notify_login(ok: bool, reason: String, coins: int) -> void:
	login_result.emit(ok, reason, coins)

@rpc("authority", "call_remote", "reliable")
func notify_register(ok: bool, reason: String) -> void:
	register_result.emit(ok, reason)

# ── Helpers ──────────────────────────────────────────────────────────────────

func _get_auth() -> Node:
	return get_node_or_null("/root/ServerMain/AuthServer")
