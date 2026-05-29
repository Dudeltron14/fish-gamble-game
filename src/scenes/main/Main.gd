extends Node2D

func _ready() -> void:
	if "--server" in OS.get_cmdline_args():
		get_tree().change_scene_to_file("res://src/server/ServerMain.tscn")
	elif ResourceLoader.exists("res://src/scenes/ui/LoginScreen.tscn"):
		get_tree().change_scene_to_file("res://src/scenes/ui/LoginScreen.tscn")
	else:
		push_warning("Main: LoginScreen.tscn not built yet — staying on placeholder scene")
