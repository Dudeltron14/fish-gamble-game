extends Node2D

const DEFAULT_PORT := 7070

func _ready() -> void:
	if "--server" in OS.get_cmdline_args():
		_start_server()
	elif ResourceLoader.exists("res://src/scenes/ui/LoginScreen.tscn"):
		get_tree().change_scene_to_file.call_deferred("res://src/scenes/ui/LoginScreen.tscn")
	else:
		push_warning("Main: LoginScreen.tscn not built yet — staying on placeholder")

func _start_server() -> void:
	var args := OS.get_cmdline_args()
	var port := DEFAULT_PORT
	var idx := args.find("--port")
	if idx != -1 and idx + 1 < args.size():
		port = args[idx + 1].to_int()
	var err := NetworkManager.start_server(port)
	if err != OK:
		push_error("Main: server failed to start on port %d" % port)
		get_tree().quit(1)
		return
	GameServer.init_server()
	get_tree().change_scene_to_file.call_deferred("res://src/scenes/world/World.tscn")
