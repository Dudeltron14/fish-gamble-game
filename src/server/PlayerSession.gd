class_name PlayerSession extends RefCounted

var peer_id: int = 0
var username: String = ""
var coins: int = 0
var position: Vector2 = Vector2.ZERO
var current_zone: String = ""
var authenticated: bool = false
var equipped_rod_id: String = ""
var equipped_bait_id: String = ""
var equipped_tackle_id: String = ""
var owned_items: Dictionary = {}  # item_id -> quantity (authoritative server-side cache)
var hook_durability: int = 0      # current uses remaining on equipped hook

func add_owned(item_id: String, delta: int) -> void:
	var q: int = owned_items.get(item_id, 0) + delta
	if q <= 0:
		owned_items.erase(item_id)
	else:
		owned_items[item_id] = q

func get_owned(item_id: String) -> int:
	return owned_items.get(item_id, 0)

func _init(p_peer_id: int) -> void:
	peer_id = p_peer_id
