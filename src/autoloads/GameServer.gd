extends Node

var sessions: Dictionary = {}
var _active := false

func init_server() -> void:
	if _active:
		return
	_active = true
	for script_path in [
		"res://src/server/AuthServer.gd",
		"res://src/server/FishingServer.gd",
		"res://src/server/ShopServer.gd",
		"res://src/server/BlackjackServer.gd",
	]:
		var node: Node = load(script_path).new()
		node.name = script_path.get_file().get_basename().to_pascal_case()
		add_child(node)
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	print("GameServer: initialized")

func _on_peer_connected(peer_id: int) -> void:
	sessions[peer_id] = PlayerSession.new(peer_id)
	print("GameServer: peer %d connected (%d total)" % [peer_id, sessions.size()])

func _on_peer_disconnected(peer_id: int) -> void:
	if sessions.erase(peer_id):
		print("GameServer: peer %d disconnected (%d remaining)" % [peer_id, sessions.size()])
	for world in get_tree().get_nodes_in_group("world"):
		world._despawn_player(peer_id)

func init_host_session(username: String) -> void:
	var session := PlayerSession.new(1)
	session.authenticated = true
	session.username = username
	session.coins = 50
	session.equipped_rod_id    = "starter_rod"
	session.equipped_bait_id   = "worm"
	session.equipped_tackle_id = "basic_hook"
	sessions[1] = session

func get_session(peer_id: int) -> PlayerSession:
	return sessions.get(peer_id, null)

func get_authenticated_session(peer_id: int) -> PlayerSession:
	var s: PlayerSession = sessions.get(peer_id, null)
	return s if (s != null and s.authenticated) else null
