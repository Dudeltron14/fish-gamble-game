extends Node

const DEFAULT_WEIGHTS := {
	"common": 0.95,
	"uncommon": 0.05,
	"rare": 0.00,
	"legendary": 0.00,
}

const MIN_AUTO_RESULT_MS := 350
const MIN_REEL_RESULT_MS := 1000
const TREASURE_MAGNET_TREASURE_CHANCE := 0.55

const JUNK_IDS := ["junk_boot", "junk_can", "junk_seaweed"]
const MAGNET_JUNK := [
	preload("res://src/resources/fish/junk_boot.tres"),
	preload("res://src/resources/fish/junk_can.tres"),
	preload("res://src/resources/fish/junk_seaweed.tres"),
]
const MAGNET_TREASURES := [
	preload("res://src/resources/fish/legendary_chest.tres"),
	preload("res://src/resources/fish/legendary_key.tres"),
]
const STARTER_COMMON_IDS := [
	"common_perch",
	"common_tropical_bluegill",
	"common_freshwater_snail",
	"common_mossback_bass",
]
const STARTER_UNCOMMON_IDS := [
	"uncommon_bass",
	"uncommon_silver_shad",
	"uncommon_red_dock_crab",
	"uncommon_sunset_conch",
]
const RARE_CATCH_WEIGHTS := {
	"rare_pearl_clam": 0.75,
}

func handle_start(peer_id: int, cast_quality: float = 1.0) -> void:
	cast_quality = clampf(cast_quality, 0.0, 1.0)
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null or session.current_zone != "DockZone":
		NetAPI.rpc_id(peer_id, "notify_fishing_start", false, "", 1.0, 1.0, 1.0)
		return
	if session.enforce_equipment_rules():
		_persist_equipment(session)

	var fish := _pick_fish(session, cast_quality)
	if fish == null:
		var tackle := ItemRegistry.get_item(session.equipped_tackle_id) as TackleData
		if tackle and tackle.id == "treasure_magnet":
			_consume_gear(peer_id, session)
		NetAPI.rpc_id(peer_id, "notify_fishing_start", false, "", 1.0, 1.0, 1.0)
		return

	var rod := ItemRegistry.get_item(session.equipped_rod_id) as RodData
	var cast_speed    := rod.cast_speed    if rod else 1.0
	var line_strength := rod.line_strength if rod else 1.0
	var bait := ItemRegistry.get_item(session.equipped_bait_id) as BaitData
	var wait_modifier := bait.wait_modifier if bait else 1.0
	var tackle := ItemRegistry.get_item(session.equipped_tackle_id) as TackleData
	var hook_react_bonus := tackle.escape_reduction if tackle else 0.0
	# Junk, Chest, and Key skip the minigame — auto-resolve on bite
	var auto_catch := fish.id.begins_with("junk_") \
		or fish.id == "legendary_chest" \
		or fish.id == "legendary_key"

	session.set_meta("pending_fish_id", fish.id)
	session.set_meta("pending_started_ms", Time.get_ticks_msec())
	session.set_meta("pending_auto_catch", auto_catch)
	session.set_meta("pending_min_result_ms", MIN_AUTO_RESULT_MS if auto_catch else MIN_REEL_RESULT_MS)

	# Consume one bait and reduce hook durability after this bite's stats are captured.
	_consume_gear(peer_id, session)

	NetAPI.rpc_id(peer_id, "notify_fishing_start", true, fish.id, fish.catch_difficulty, cast_speed, line_strength, wait_modifier, hook_react_bonus, auto_catch)

func handle_result(peer_id: int, succeeded: bool) -> void:
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null or not session.has_meta("pending_fish_id"):
		return

	var fish_id: String = session.get_meta("pending_fish_id")
	var started_ms: int = int(session.get_meta("pending_started_ms", 0))
	var min_result_ms: int = int(session.get_meta("pending_min_result_ms", MIN_REEL_RESULT_MS))
	var auto_catch: bool = bool(session.get_meta("pending_auto_catch", false))
	_clear_pending_fish(session)

	if not succeeded:
		NetAPI.rpc_id(peer_id, "notify_fishing_result", false, fish_id, 0, session.coins)
		return

	var elapsed_ms: int = Time.get_ticks_msec() - started_ms
	if elapsed_ms < min_result_ms:
		NetAPI.rpc_id(peer_id, "notify_fishing_result", false, fish_id, 0, session.coins)
		return

	var fish: FishData = ItemRegistry.get_item(fish_id) as FishData
	if fish == null:
		return

	var expected_auto_catch: bool = fish.id.begins_with("junk_") \
		or fish.id == "legendary_chest" \
		or fish.id == "legendary_key"
	if auto_catch != expected_auto_catch:
		NetAPI.rpc_id(peer_id, "notify_fishing_result", false, fish_id, 0, session.coins)
		return

	# Payout = rarity base × difficulty × hook multiplier
	# base_coin_value represents the rarity tier base; difficulty scales for work required
	var multiplier := 1.0
	var tackle := ItemRegistry.get_item(session.equipped_tackle_id) as TackleData
	if tackle:
		multiplier = tackle.coin_multiplier

	var earned := int(fish.base_coin_value * fish.catch_difficulty * multiplier)
	session.coins += earned
	_save_coins(session)
	NetAPI.rpc_id(peer_id, "notify_fishing_result", true, fish_id, earned, session.coins)
	NetAPI.rpc("notify_player_catch", peer_id, fish_id)

func _pick_fish(session: PlayerSession, cast_quality: float = 1.0) -> FishData:
	# Treasure Magnet finds a chest or key often enough to profit across one 10-use hook.
	var tackle := ItemRegistry.get_item(session.equipped_tackle_id) as TackleData
	if tackle and tackle.id == "treasure_magnet":
		var treasure_chance := _magnet_treasure_chance(tackle.durability)
		if randf() < treasure_chance:
			return MAGNET_TREASURES.pick_random() as FishData
		return MAGNET_JUNK.pick_random() as FishData

	# Apply bait rarity_weights
	var weights := DEFAULT_WEIGHTS.duplicate()
	var bait := ItemRegistry.get_item(session.equipped_bait_id) as BaitData
	if bait:
		if bait.id == "worm":
			return _pick_worm_fish(cast_quality)
		weights = bait.rarity_weights.duplicate()
	else:
		return _pick_no_bait_fish(cast_quality)

	# Apply rod rarity_bonus
	var rod := ItemRegistry.get_item(session.equipped_rod_id) as RodData
	if rod and rod.rarity_bonus > 0.0:
		var bonus := rod.rarity_bonus
		weights["common"] = maxf(0.0, weights.get("common", 0.0) - bonus)
		weights["rare"]   = weights.get("rare", 0.0)   + bonus * 0.7
		weights["legendary"] = weights.get("legendary", 0.0) + bonus * 0.3

	# Apply cast quality bonus/penalty (±0.10 max, centred at 0.5)
	# Perfect cast (1.0): +0.10 toward rare/legendary
	# Terrible cast (0.0): −0.10 shifted toward common
	var cast_bonus := (cast_quality - 0.5) * 0.2
	if cast_bonus > 0.0:
		weights["common"] = maxf(0.0, weights.get("common", 0.0) - cast_bonus)
		weights["rare"]       = weights.get("rare", 0.0)       + cast_bonus * 0.7
		weights["legendary"]  = weights.get("legendary", 0.0)  + cast_bonus * 0.3
	elif cast_bonus < 0.0:
		var penalty := -cast_bonus
		weights["rare"]      = maxf(0.0, weights.get("rare", 0.0)      - penalty * 0.7)
		weights["legendary"] = maxf(0.0, weights.get("legendary", 0.0) - penalty * 0.3)
		weights["common"]    = weights.get("common", 0.0) + penalty
	if bait and bait.id == "magic_bait":
		weights["common"] = 0.0

	# Normalize weights so they always sum to 1.0.
	# Needed when common=0 (Magic Bait) absorbs rod/cast bonuses without a pool to draw from.
	var total := 0.0
	for v: float in weights.values(): total += v
	if total > 0.0:
		for key: String in weights:
			weights[key] = weights[key] / total

	var rarity := _weighted_rarity(weights)
	var candidates: Array = ItemRegistry.fish.values().filter(
		func(f: FishData) -> bool: return f.rarity == rarity and not _is_junk(f.id)
	)
	if candidates.is_empty():
		candidates = ItemRegistry.fish.values().filter(
			func(f: FishData) -> bool: return not _is_junk(f.id)
		)
	if candidates.is_empty():
		return null
	return _pick_weighted_candidate(candidates)

func _pick_no_bait_fish(cast_quality: float) -> FishData:
	var roll := randf()
	var junk_chance := lerpf(0.65, 0.35, clampf(cast_quality, 0.0, 1.0))
	if roll < junk_chance:
		var junk := _fish_candidates(JUNK_IDS)
		if not junk.is_empty():
			return junk[randi() % junk.size()]
	var common := _fish_candidates(STARTER_COMMON_IDS)
	if not common.is_empty():
		return common[randi() % common.size()]
	var fallback := _fish_candidates(JUNK_IDS)
	return fallback[randi() % fallback.size()] if not fallback.is_empty() else ItemRegistry.get_item("common_perch") as FishData

func _pick_worm_fish(cast_quality: float) -> FishData:
	var roll := randf()
	var quality := clampf(cast_quality, 0.0, 1.0)
	var junk_chance := lerpf(0.12, 0.03, quality)
	var uncommon_chance := lerpf(0.18, 0.28, quality)
	if roll < junk_chance:
		var junk := _fish_candidates(JUNK_IDS)
		if not junk.is_empty():
			return junk[randi() % junk.size()]
	if roll < 1.0 - uncommon_chance:
		var common := _fish_candidates(STARTER_COMMON_IDS)
		if not common.is_empty():
			return common[randi() % common.size()]
	var uncommon := _fish_candidates(STARTER_UNCOMMON_IDS)
	if not uncommon.is_empty():
		return uncommon[randi() % uncommon.size()]
	var fallback := _fish_candidates(["common_perch", "common_mossback_bass", "uncommon_bass", "uncommon_silver_shad"])
	return fallback[randi() % fallback.size()] if not fallback.is_empty() else null

func _pick_weighted_candidate(candidates: Array) -> FishData:
	var total := 0.0
	for fish: FishData in candidates:
		total += _candidate_weight(fish)
	if total <= 0.0:
		return candidates[randi() % candidates.size()]
	var roll := randf() * total
	var cumulative := 0.0
	for fish: FishData in candidates:
		cumulative += _candidate_weight(fish)
		if roll <= cumulative:
			return fish
	return candidates.back()

func _candidate_weight(fish: FishData) -> float:
	if fish.rarity == "rare":
		return float(RARE_CATCH_WEIGHTS.get(fish.id, 1.0))
	return 1.0

func _is_junk(fish_id: String) -> bool:
	return fish_id.begins_with("junk_")

func _fish_candidates(ids: Array[String]) -> Array[FishData]:
	var candidates: Array[FishData] = []
	for id: String in ids:
		var fish := ItemRegistry.get_item(id) as FishData
		if fish:
			candidates.append(fish)
	return candidates

func _magnet_treasure_chance(_durability: int) -> float:
	return TREASURE_MAGNET_TREASURE_CHANCE

func _weighted_rarity(weights: Dictionary) -> String:
	var roll := randf()
	var cumulative := 0.0
	for rarity in ["common", "uncommon", "rare", "legendary"]:
		cumulative += weights.get(rarity, 0.0)
		if roll < cumulative:
			return rarity
	return "common"

func _clear_pending_fish(session: PlayerSession) -> void:
	for key: String in ["pending_fish_id", "pending_started_ms", "pending_auto_catch", "pending_min_result_ms"]:
		if session.has_meta(key):
			session.remove_meta(key)

func _consume_gear(peer_id: int, session: PlayerSession) -> void:
	# Deduct one bait use
	if not session.equipped_bait_id.is_empty():
		session.add_owned(session.equipped_bait_id, -1)
		var bait_qty := session.get_owned(session.equipped_bait_id)
		_persist_decrement(session, session.equipped_bait_id)
		NetAPI.rpc_id(peer_id, "notify_inventory_updated", session.equipped_bait_id, bait_qty)
		if bait_qty <= 0:
			session.equipped_bait_id = ""
			_persist_equipment(session)
			NetAPI.rpc_id(peer_id, "notify_bait_empty")

	# Deduct one hook durability (not quantity — hook survives multiple casts)
	if not session.equipped_tackle_id.is_empty():
		var tackle_id := session.equipped_tackle_id
		var tackle := ItemRegistry.get_item(tackle_id) as TackleData
		var max_dur := tackle.durability if tackle else 10
		session.set_current_hook_durability(maxi(0, session.hook_durability - 1))
		if session.hook_durability <= 0:
			# Hook broke — consume one from inventory
			session.add_owned(tackle_id, -1)
			var hook_qty := session.get_owned(tackle_id)
			_persist_decrement(session, tackle_id)
			NetAPI.rpc_id(peer_id, "notify_inventory_updated", tackle_id, hook_qty)
			if hook_qty <= 0:
				session.hook_durabilities.erase(tackle_id)
				session.equipped_tackle_id = ""
				session.hook_durability = 0
				_persist_equipment(session)
				NetAPI.rpc_id(peer_id, "notify_hook_broken")
			else:
				# Player still has hooks — re-equip next one at full durability
				session.set_current_hook_durability(max_dur)
				_persist_equipment(session)
				NetAPI.rpc_id(peer_id, "notify_hook_durability", session.hook_durability, max_dur)
		else:
			_persist_equipment(session)
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

func _persist_equipment(session: PlayerSession) -> void:
	var auth := GameServer.get_node_or_null("AuthServer")
	if auth != null and auth.has_method("save_equipment"):
		auth.save_equipment(session)
