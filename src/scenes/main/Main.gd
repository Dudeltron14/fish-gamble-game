extends Node2D

const DEFAULT_PORT := 7070

func _ready() -> void:
	var args := _get_app_args()
	if "--reset-password" in args:
		_reset_password_command.call_deferred()
	elif "--server" in args:
		_start_server()
	elif ResourceLoader.exists("res://src/scenes/ui/LoginScreen.tscn"):
		get_tree().change_scene_to_file.call_deferred("res://src/scenes/ui/LoginScreen.tscn")
	else:
		push_warning("Main: LoginScreen.tscn not built yet — staying on placeholder")

func _start_server() -> void:
	var args := _get_app_args()
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

func _reset_password_command() -> void:
	var args := _get_app_args()
	var idx := args.find("--reset-password")
	if idx == -1 or idx + 1 >= args.size():
		push_error("Usage: --reset-password <username> [new_password]")
		get_tree().quit(2)
		return

	var username := args[idx + 1].strip_edges()
	var new_password := ""
	var generated := false
	if idx + 2 < args.size() and not str(args[idx + 2]).begins_with("--"):
		new_password = str(args[idx + 2])
	else:
		new_password = _generate_temporary_password()
		generated = true

	var auth: Node = load("res://src/server/AuthServer.gd").new()
	auth.name = "AuthServer"
	add_child(auth)
	await get_tree().process_frame

	var ok: bool = auth.reset_password(username, new_password)
	if ok:
		if generated:
			print("Temporary password for '%s': %s" % [username, new_password])
		else:
			print("Password reset complete for '%s'." % username)
		get_tree().quit(0)
	else:
		get_tree().quit(1)

func _generate_temporary_password() -> String:
	var bytes := PackedByteArray()
	bytes.resize(9)
	var crypto := Crypto.new()
	bytes = crypto.generate_random_bytes(bytes.size())
	return "Fish-" + bytes.hex_encode()

func _get_app_args() -> Array[String]:
	var args: Array[String] = []
	for arg in OS.get_cmdline_args():
		args.append(arg)
	for arg in OS.get_cmdline_user_args():
		args.append(arg)
	return args
