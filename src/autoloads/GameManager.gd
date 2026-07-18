extends Node

signal coins_changed(new_amount: int)
signal zone_hint_changed(hint: String)
signal equipped_changed()
signal owned_changed()
@warning_ignore("unused_signal")
signal hook_durability_changed(current: int, max_val: int)
signal camera_zoom_changed(value: float)
signal fishing_result_completed()
signal catch_inventory_changed()

var current_player_name: String = ""
var current_coins: int = 0
var current_zone: String = ""
var equipped_rod_id: String = ""
var equipped_bait_id: String = ""
var equipped_tackle_id: String = ""
var is_hosting: bool = false
var owned_items: Dictionary = {}  # item_id -> quantity
var hook_durability: int = 0
var hook_max_durability: int = 0
var camera_zoom: float = 4.0
var catch_inventory: Array = []  # [{db_id, fish_id, sell_value}, ...]

const MAX_CATCH_SLOTS := 5

const ZONE_HINTS := {
	"DockZone":   "HOLD E to Fish",
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

func set_player_data(player_name: String, coins: int) -> void:
	current_player_name = player_name
	set_coins(coins)

func set_coins(amount: int) -> void:
	current_coins = amount
	coins_changed.emit(current_coins)

func set_zone(zone_name: String) -> void:
	current_zone = zone_name
	zone_hint_changed.emit(ZONE_HINTS.get(zone_name, ""))

func set_owned_items(items: Dictionary) -> void:
	owned_items = items.duplicate()
	owned_changed.emit()

func set_owned(item_id: String, qty: int) -> void:
	if qty <= 0:
		owned_items.erase(item_id)
	else:
		owned_items[item_id] = qty
	owned_changed.emit()

func get_owned(item_id: String) -> int:
	return owned_items.get(item_id, 0)

func set_catch_inventory(slots: Array) -> void:
	catch_inventory = slots.duplicate(true)
	catch_inventory_changed.emit()

func catch_inventory_is_full() -> bool:
	return catch_inventory.size() >= MAX_CATCH_SLOTS

func set_camera_zoom(value: float) -> void:
	camera_zoom = clampf(value, 1.0, 4.0)
	camera_zoom_changed.emit(camera_zoom)
