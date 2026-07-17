extends SceneTree

const GameServerScript = preload("res://src/autoloads/GameServer.gd")
const NetworkManagerScript = preload("res://src/autoloads/NetworkManager.gd")
const PlayerSessionScript = preload("res://src/server/PlayerSession.gd")

func _init() -> void:
	call_deferred("_check")

func _check() -> void:
	var network = NetworkManagerScript.new()
	assert(network.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED)
	network.free()
	var server = GameServerScript.new()
	var guest = PlayerSessionScript.new(1)
	var player = PlayerSessionScript.new(2)
	player.authenticated = true
	server.sessions = {1: guest, 2: player}
	assert(server.get_authenticated_player_count() == 1)
	server.free()
	quit()
