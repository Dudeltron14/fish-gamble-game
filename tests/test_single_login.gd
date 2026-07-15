extends SceneTree

const GameServerScript := preload("res://src/autoloads/GameServer.gd")
const PlayerSessionScript := preload("res://src/server/PlayerSession.gd")

func _init() -> void:
	var server := GameServerScript.new()
	var player := PlayerSessionScript.new(1)
	player.authenticated = true
	player.username = "angler"
	server.sessions = {1: player, 2: PlayerSessionScript.new(2)}
	assert(server.is_username_authenticated("angler"))
	assert(not server.is_username_authenticated("other"))
	server.free()
	quit()
