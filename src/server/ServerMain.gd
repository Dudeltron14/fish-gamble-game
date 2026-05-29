extends Node

const DEFAULT_PORT := 7070

var sessions: Dictionary = {}  # peer_id (int) -> PlayerSession

var auth_server: Node  # AuthServer child node

func _ready() -> void:
	auth_server = preload("res://src/server/AuthServer.gd").new()
	auth_server.name = "AuthServer"
	add_child(auth_server)

	var port := _get_port_arg()
	var err := NetworkManager.start_server(port)
	if err != OK:
		push_error("ServerMain: could not start server on port %d" % port)
		get_tree().quit(1)
		return
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	print("ServerMain: listening on port %d" % port)

func _get_port_arg() -> int:
	var args := OS.get_cmdline_args()
	var idx := args.find("--port")
	if idx != -1 and idx + 1 < args.size():
		return args[idx + 1].to_int()
	return DEFAULT_PORT

func _on_peer_connected(peer_id: int) -> void:
	sessions[peer_id] = PlayerSession.new(peer_id)
	print("ServerMain: peer %d connected (%d total)" % [peer_id, sessions.size()])

func _on_peer_disconnected(peer_id: int) -> void:
	if sessions.erase(peer_id):
		print("ServerMain: peer %d disconnected (%d remaining)" % [peer_id, sessions.size()])

func get_session(peer_id: int) -> PlayerSession:
	return sessions.get(peer_id, null)

func get_authenticated_session(peer_id: int) -> PlayerSession:
	var s: PlayerSession = sessions.get(peer_id, null)
	return s if (s != null and s.authenticated) else null
