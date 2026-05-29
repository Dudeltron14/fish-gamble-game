class_name PlayerSession extends RefCounted

var peer_id: int = 0
var username: String = ""
var coins: int = 0
var position: Vector2 = Vector2.ZERO
var current_zone: String = ""
var authenticated: bool = false

func _init(p_peer_id: int) -> void:
	peer_id = p_peer_id
