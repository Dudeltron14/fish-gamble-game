extends Node

signal coins_changed(new_amount: int)
signal zone_hint_changed(hint: String)
signal equipped_changed()
signal owned_changed()
@warning_ignore("unused_signal")
signal hook_durability_changed(current: int, max_val: int)
signal camera_zoom_changed(value: float)
signal cosmetics_changed(skin_id: String, bobber_id: String)
signal fishing_result_completed()

var current_player_name: String = ""
var current_coins: int = 0
var current_zone: String = ""
var world_phase: String = "day"
var world_time_remaining: int = 900
var equipped_rod_id: String = ""
var equipped_bait_id: String = ""
var equipped_tackle_id: String = ""
var equipped_skin_id: String = ""
var equipped_bobber_id: String = ""
var is_hosting: bool = false
var owned_items: Dictionary = {}  # item_id -> quantity
var hook_durability: int = 0
var hook_max_durability: int = 0
var camera_zoom: float = 2.0

const ZONE_HINTS := {
	"DockZone":   "HOLD E to Fish",
	"ShopZone":   "Press E to open shop",
	"CasinoZone": "Press E to enter casino",
	"MailboxZone": "Press E to check mailbox",
	"JukeboxZone": "Press E to choose music",
	"HarborMasterZone": "Press E to speak with Harbor Master",
	"PierZone": "Pier fishing — hold E to cast",
	"LighthouseRocksZone": "Lighthouse rocks — night catches favor rare fish",
	"ReedbankZone": "Reedbank fishing — harbor minnows gather here",
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

func get_equipped_summary() -> String:
	var rod := ItemRegistry.get_item(equipped_rod_id) as ItemData
	var bait := ItemRegistry.get_item(equipped_bait_id) as ItemData
	var hook := ItemRegistry.get_item(equipped_tackle_id) as TackleData
	var rod_text := rod.display_name if rod else "—"
	var bait_text := "%s ×%d" % [bait.display_name, get_owned(equipped_bait_id)] if bait else "—"
	var hook_text := "%s %d/%d" % [hook.display_name, hook_durability, hook_max_durability] if hook and hook_max_durability > 0 else (hook.display_name if hook else "—")
	return "Rod: %s  Bait: %s  Hook: %s" % [rod_text, bait_text, hook_text]

func set_equipped_cosmetics(skin_id: String, bobber_id: String) -> void:
	equipped_skin_id = skin_id
	equipped_bobber_id = bobber_id
	cosmetics_changed.emit(skin_id, bobber_id)

func set_camera_zoom(value: float) -> void:
	camera_zoom = clampf(value, 1.0, 4.0)
	camera_zoom_changed.emit(camera_zoom)
