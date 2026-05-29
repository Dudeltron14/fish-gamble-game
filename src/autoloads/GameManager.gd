extends Node

signal scene_changed(scene_path: String)

var current_player_name: String = ""
var current_coins: int = 0

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_quit_requested()

func _on_quit_requested() -> void:
	get_tree().quit()

func go_to_scene(path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(path)
	scene_changed.emit(path)

func set_player_data(player_name: String, coins: int) -> void:
	current_player_name = player_name
	current_coins = coins

func add_coins(amount: int) -> void:
	current_coins += amount

func spend_coins(amount: int) -> bool:
	if current_coins < amount:
		return false
	current_coins -= amount
	return true
