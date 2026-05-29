extends Node

var sessions: Dictionary = {}  # peer_id (int) -> PlayerSession
var _active := false

func init_server() -> void:
	if _active:
		return
	_active = true
	var auth := preload("res://src/server/AuthServer.gd").new()
	auth.name = "AuthServer"
	add_child(auth)
	var fishing := preload("res://src/server/FishingServer.gd").new()
	fishing.name = "FishingServer"
	add_child(fishing)
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

func get_session(peer_id: int) -> PlayerSession:
	return sessions.get(peer_id, null)

func get_authenticated_session(peer_id: int) -> PlayerSession:
	var s: PlayerSession = sessions.get(peer_id, null)
	return s if (s != null and s.authenticated) else null
