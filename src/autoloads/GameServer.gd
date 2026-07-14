extends Node

var sessions: Dictionary = {}
var _active := false

const STARTER_COINS := 50
const STARTER_ROD_ID := "starter_rod"
const STARTER_BAIT_ID := "worm"
const STARTER_TACKLE_ID := "basic_hook"

func init_server() -> void:
	if _active:
		return
	_active = true
	for script_path in [
		"res://src/server/AuthServer.gd",
		"res://src/server/FishingServer.gd",
		"res://src/server/ShopServer.gd",
		"res://src/server/BlackjackServer.gd",
	]:
		var node: Node = load(script_path).new()
		node.name = script_path.get_file().get_basename().to_pascal_case()
		add_child(node)
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	print("GameServer: initialized")

func _on_peer_connected(peer_id: int) -> void:
	sessions[peer_id] = PlayerSession.new(peer_id)
	print("GameServer: peer %d connected (%d total)" % [peer_id, sessions.size()])

func _on_peer_disconnected(peer_id: int) -> void:
	if sessions.erase(peer_id):
		print("GameServer: peer %d disconnected (%d remaining)" % [peer_id, sessions.size()])
	for world in get_tree().get_nodes_in_group("world"):
		world._despawn_player(peer_id)

func get_starter_items() -> Dictionary:
	var items := {}
	items[STARTER_ROD_ID] = 1
	items[STARTER_BAIT_ID] = get_starter_bait_quantity()
	items[STARTER_TACKLE_ID] = 1
	return items

func get_starter_bait_quantity() -> int:
	var bait := ItemRegistry.get_item(STARTER_BAIT_ID) as BaitData
	return bait.uses_per_stack if bait else 1

func get_starter_hook_durability() -> int:
	var tackle := ItemRegistry.get_item(STARTER_TACKLE_ID) as TackleData
	return tackle.durability if tackle else 0

func get_session(peer_id: int) -> PlayerSession:
	return sessions.get(peer_id, null)

func get_authenticated_session(peer_id: int) -> PlayerSession:
	var s: PlayerSession = sessions.get(peer_id, null)
	return s if (s != null and s.authenticated) else null
