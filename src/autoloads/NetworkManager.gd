extends Node

signal connected_to_server()
signal connection_failed()
signal server_disconnected()
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

const DEFAULT_PORT := 7070

var _peer: WebSocketMultiplayerPeer = null

func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func start_server(port: int = DEFAULT_PORT) -> Error:
	_peer = WebSocketMultiplayerPeer.new()
	var err := _peer.create_server(port)
	if err != OK:
		push_error("NetworkManager: failed to start server on port %d — %s" % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = _peer
	print("NetworkManager: server listening on port %d" % port)
	return OK

func connect_to_server(address: String, port: int = DEFAULT_PORT) -> Error:
	_peer = WebSocketMultiplayerPeer.new()
	var url := "ws://%s:%d" % [address, port]
	var err := _peer.create_client(url)
	if err != OK:
		push_error("NetworkManager: failed to connect to %s — %s" % [url, error_string(err)])
		return err
	multiplayer.multiplayer_peer = _peer
	return OK

func disconnect_from_server() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = null

func is_server() -> bool:
	return multiplayer.is_server()

func get_my_id() -> int:
	return multiplayer.get_unique_id()

func _on_connected_to_server() -> void:
	connected_to_server.emit()

func _on_connection_failed() -> void:
	connection_failed.emit()

func _on_server_disconnected() -> void:
	server_disconnected.emit()

func _on_peer_connected(id: int) -> void:
	peer_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	peer_disconnected.emit(id)
