extends Node

signal scene_changed(scene_path: String)
signal coins_changed(new_amount: int)
signal zone_hint_changed(hint: String)
signal equipped_changed()

var current_player_name: String = ""
var current_coins: int = 0
var current_zone: String = ""
var equipped_rod_id: String = ""
var equipped_bait_id: String = ""
var equipped_tackle_id: String = ""

const ZONE_HINTS := {
	"DockZone":   "Press E to fish",
	"ShopZone":   "Press E to open shop",
	"CasinoZone": "Press E to enter casino",
}

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
	set_coins(coins)

func set_coins(amount: int) -> void:
	current_coins = amount
	coins_changed.emit(current_coins)

func add_coins(amount: int) -> void:
	set_coins(current_coins + amount)

func spend_coins(amount: int) -> bool:
	if current_coins < amount:
		return false
	set_coins(current_coins - amount)
	return true

func set_zone(zone_name: String) -> void:
	current_zone = zone_name
	zone_hint_changed.emit(ZONE_HINTS.get(zone_name, ""))
