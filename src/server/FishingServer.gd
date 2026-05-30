extends Node

const DEFAULT_WEIGHTS := {
	"common": 0.65,
	"uncommon": 0.25,
	"rare": 0.09,
	"legendary": 0.01,
}

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

	# Consume one bait and reduce hook durability — happens on every bite
	_consume_gear(peer_id, session)

	var rod := ItemRegistry.get_item(session.equipped_rod_id) as RodData
	var cast_speed := rod.cast_speed if rod else 1.0
	NetAPI.rpc_id(peer_id, "notify_fishing_start", true, fish.id, fish.catch_difficulty, cast_speed)

func handle_result(peer_id: int, succeeded: bool) -> void:
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null or not session.has_meta("pending_fish_id"):
		return

	var fish_id: String = session.get_meta("pending_fish_id")
	session.remove_meta("pending_fish_id")

	if not succeeded:
		NetAPI.rpc_id(peer_id, "notify_fishing_result", false, fish_id, 0, session.coins)
		return

	var fish: FishData = ItemRegistry.get_item(fish_id) as FishData
	if fish == null:
		return

	# Apply tackle coin_multiplier (10.4)
	var multiplier := 1.0
	var tackle := ItemRegistry.get_item(session.equipped_tackle_id) as TackleData
	if tackle:
		multiplier = tackle.coin_multiplier

	var earned := int(fish.base_coin_value * multiplier)
	session.coins += earned
	_save_coins(session)
	NetAPI.rpc_id(peer_id, "notify_fishing_result", true, fish_id, earned, session.coins)

func _pick_fish(session: PlayerSession) -> FishData:
	# Apply bait rarity_weights (10.3)
	var weights := DEFAULT_WEIGHTS.duplicate()
	var bait := ItemRegistry.get_item(session.equipped_bait_id) as BaitData
	if bait:
		weights = bait.rarity_weights.duplicate()

	# Apply rod rarity_bonus — shifts weight from common into rare tiers (10.5)
	var rod := ItemRegistry.get_item(session.equipped_rod_id) as RodData
	if rod and rod.rarity_bonus > 0.0:
		var bonus := rod.rarity_bonus
		weights["common"] = maxf(0.0, weights.get("common", 0.0) - bonus)
		weights["rare"]   = weights.get("rare", 0.0)   + bonus * 0.7
		weights["legendary"] = weights.get("legendary", 0.0) + bonus * 0.3

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

func _consume_gear(peer_id: int, session: PlayerSession) -> void:
	# Deduct one bait use
	if not session.equipped_bait_id.is_empty():
		session.add_owned(session.equipped_bait_id, -1)
		var bait_qty := session.get_owned(session.equipped_bait_id)
		_persist_decrement(session, session.equipped_bait_id)
		NetAPI.rpc_id(peer_id, "notify_inventory_updated", session.equipped_bait_id, bait_qty)
		if bait_qty <= 0:
			session.equipped_bait_id = ""
			NetAPI.rpc_id(peer_id, "notify_bait_empty")

	# Deduct one hook durability (not quantity — hook survives multiple casts)
	if not session.equipped_tackle_id.is_empty():
		session.hook_durability = maxi(0, session.hook_durability - 1)
		var tackle := ItemRegistry.get_item(session.equipped_tackle_id) as TackleData
		var max_dur := tackle.durability if tackle else 10
		if session.hook_durability <= 0:
			# Hook broke — consume one from inventory
			session.add_owned(session.equipped_tackle_id, -1)
			var hook_qty := session.get_owned(session.equipped_tackle_id)
			_persist_decrement(session, session.equipped_tackle_id)
			NetAPI.rpc_id(peer_id, "notify_inventory_updated", session.equipped_tackle_id, hook_qty)
			if hook_qty <= 0:
				session.equipped_tackle_id = ""
				NetAPI.rpc_id(peer_id, "notify_hook_broken")
			else:
				# Player still has hooks — re-equip next one at full durability
				session.hook_durability = max_dur
				NetAPI.rpc_id(peer_id, "notify_hook_durability", session.hook_durability, max_dur)
		else:
			NetAPI.rpc_id(peer_id, "notify_hook_durability", session.hook_durability, max_dur)

func _persist_decrement(session: PlayerSession, item_id: String) -> void:
	var auth := GameServer.get_node_or_null("AuthServer")
	if auth == null or auth._db == null:
		return
	auth._db.query_with_bindings("""
		UPDATE inventory SET quantity = MAX(0, quantity - 1)
		WHERE player_id = (SELECT id FROM players WHERE username = ?)
		AND item_id = ?
	""", [session.username, item_id])

func _save_coins(session: PlayerSession) -> void:
	var auth := GameServer.get_node_or_null("AuthServer")
	if auth == null or auth._db == null:
		return
	auth._db.query_with_bindings(
		"UPDATE players SET coins = ? WHERE username = ?",
		[session.coins, session.username]
	)
