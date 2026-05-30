extends Node

# Default rarity weights used when no bait equipped
const DEFAULT_WEIGHTS := {
	"common": 0.65,
	"uncommon": 0.25,
	"rare": 0.09,
	"legendary": 0.01,
}

# Called by NetAPI when a client requests to start fishing
func handle_start(peer_id: int) -> void:
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null or session.current_zone != "DockZone":
		NetAPI.rpc_id(peer_id, "notify_fishing_start", false, "", 1.0)
		return

	var fish := _pick_fish(session)
	if fish == null:
		NetAPI.rpc_id(peer_id, "notify_fishing_start", false, "", 1.0)
		return

	session.set_meta("pending_fish_id", fish.id)
	NetAPI.rpc_id(peer_id, "notify_fishing_start", true, fish.id, fish.catch_difficulty)

# Called by NetAPI when a client reports minigame result
func handle_result(peer_id: int, succeeded: bool) -> void:
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null or not session.has_meta("pending_fish_id"):
		return

	var fish_id: String = session.get_meta("pending_fish_id")
	session.remove_meta("pending_fish_id")

	if not succeeded:
		NetAPI.rpc_id(peer_id, "notify_fishing_result", false, fish_id, 0)
		return

	var fish: FishData = ItemRegistry.get_item(fish_id) as FishData
	if fish == null:
		return

	var earned := fish.base_coin_value
	session.coins += earned
	_save_coins(session)
	NetAPI.rpc_id(peer_id, "notify_fishing_result", true, fish_id, earned, session.coins)

func _pick_fish(session: PlayerSession) -> FishData:
	var weights := DEFAULT_WEIGHTS.duplicate()
	# TODO: merge bait rarity_weights from equipped bait when inventory exists

	var rarity := _weighted_rarity(weights)
	var candidates: Array = ItemRegistry.fish.values().filter(
		func(f: FishData) -> bool: return f.rarity == rarity
	)
	if candidates.is_empty():
		candidates = ItemRegistry.fish.values()
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]

func _weighted_rarity(weights: Dictionary) -> String:
	var roll := randf()
	var cumulative := 0.0
	for rarity in ["common", "uncommon", "rare", "legendary"]:
		cumulative += weights.get(rarity, 0.0)
		if roll < cumulative:
			return rarity
	return "common"

func _save_coins(session: PlayerSession) -> void:
	var auth := GameServer.get_node_or_null("AuthServer")
	if auth == null or auth._db == null:
		return
	auth._db.query_with_bindings(
		"UPDATE players SET coins = ? WHERE username = ?",
		[session.coins, session.username]
	)
