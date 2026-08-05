extends Node

const FREE_REROLLS := 3
const REROLL_COST := 25
const QUEST_RESET_SECONDS := 24 * 60 * 60
const DIFFICULTIES := [
	{"name": "Easy", "weight": 60, "reward": 25, "fish": 3, "hand": 15, "casino": 30},
	{"name": "Medium", "weight": 27, "reward": 70, "fish": 5, "hand": 35, "casino": 80},
	{"name": "Hard", "weight": 10, "reward": 180, "fish": 8, "hand": 75, "casino": 180},
	{"name": "Legendary", "weight": 3, "reward": 550, "fish": 12, "hand": 160, "casino": 400},
]

func handle_stats(peer_id: int, requested_username: String = "") -> void:
	var session := _at_harbor(peer_id)
	if session == null: return
	var db = _db()
	var username := requested_username.strip_edges() if not requested_username.strip_edges().is_empty() else session.username
	var player_id := _player_id(username)
	if db == null or player_id < 0: return
	db.query_with_bindings("SELECT coins FROM players WHERE id = ?", [player_id])
	var coins := int(db.query_result[0].coins) if not db.query_result.is_empty() else 0
	db.query_with_bindings("SELECT fish_id, caught_count, got_away_count, best_measurement FROM player_fish_stats WHERE player_id = ? ORDER BY caught_count DESC, fish_id", [player_id])
	var fish: Array = db.query_result.duplicate()
	var viewer_id := _player_id(session.username)
	var viewer_fish: Array = fish.duplicate(true) if viewer_id == player_id else []
	if viewer_id >= 0 and viewer_id != player_id:
		db.query_with_bindings("SELECT fish_id, caught_count, got_away_count, best_measurement FROM player_fish_stats WHERE player_id = ?", [viewer_id])
		viewer_fish = db.query_result.duplicate()
	db.query_with_bindings("SELECT item_id, uses FROM player_gear_stats WHERE player_id = ? ORDER BY uses DESC", [player_id])
	var gear: Array = db.query_result.duplicate()
	db.query_with_bindings("SELECT * FROM player_career_stats WHERE player_id = ?", [player_id])
	var career: Dictionary = db.query_result[0] if not db.query_result.is_empty() else {}
	var viewer_career: Dictionary = career.duplicate(true) if viewer_id == player_id else {}
	if viewer_id >= 0 and viewer_id != player_id:
		db.query_with_bindings("SELECT * FROM player_career_stats WHERE player_id = ?", [viewer_id])
		viewer_career = db.query_result[0] if not db.query_result.is_empty() else {}
	if username == session.username:
		career["time_played_seconds"] = int(career.get("time_played_seconds", 0)) + maxi(0, (Time.get_ticks_msec() - session.connected_at_ms) / 1000)
		viewer_career = career.duplicate(true)
	db.query_with_bindings("SELECT COUNT(*) AS total FROM player_login_days WHERE player_id = ?", [player_id])
	career["login_days"] = int(db.query_result[0].total) if not db.query_result.is_empty() else 0
	db.query_with_bindings("SELECT COUNT(*) AS total FROM player_login_days WHERE player_id = ?", [viewer_id])
	viewer_career["login_days"] = int(db.query_result[0].total) if not db.query_result.is_empty() else 0
	db.query_with_bindings("SELECT coins FROM players WHERE id = ?", [viewer_id])
	var viewer_coins := int(db.query_result[0].coins) if not db.query_result.is_empty() else 0
	db.query("SELECT username FROM players ORDER BY coins DESC, username LIMIT 100")
	NetAPI.rpc_id(peer_id, "notify_harbor_stats", {"username": username, "fish": fish, "viewer_fish": viewer_fish, "gear": gear, "career": career, "viewer_career": viewer_career, "coins": coins, "viewer_coins": viewer_coins, "players": db.query_result})

func handle_quests(peer_id: int) -> void:
	var session := _at_harbor(peer_id)
	if session == null: return
	_send_quests(peer_id, session)

func handle_reroll(peer_id: int, slot: int) -> void:
	var session := _at_harbor(peer_id)
	if session == null or slot < 0 or slot > 2: return
	var db = _db(); var player_id := _player_id(session.username)
	if db == null or player_id < 0: return
	var day := _quest_day(player_id)
	_ensure_day(player_id, day)
	db.query_with_bindings("SELECT progress, target, claimed FROM daily_quests WHERE player_id = ? AND day_key = ? AND slot = ?", [player_id, day, slot])
	if not db.query_result.is_empty() and (int(db.query_result[0].claimed) != 0 or int(db.query_result[0].progress) >= int(db.query_result[0].target)):
		NetAPI.rpc_id(peer_id, "notify_daily_quest_result", false, "Completed ledger lines reset after the server timer.")
		return
	db.query_with_bindings("SELECT free_rerolls_used FROM daily_quest_state WHERE player_id = ? AND day_key = ?", [player_id, day])
	var used := int(db.query_result[0].free_rerolls_used) if not db.query_result.is_empty() else 0
	if used < FREE_REROLLS:
		db.query_with_bindings("UPDATE daily_quest_state SET free_rerolls_used = free_rerolls_used + 1 WHERE player_id = ? AND day_key = ?", [player_id, day])
		_increment_by_id(player_id, "free_quest_rerolls", 1)
	elif session.coins >= REROLL_COST:
		session.coins -= REROLL_COST
		db.query_with_bindings("UPDATE players SET coins = ? WHERE id = ?", [session.coins, player_id])
		_increment_by_id(player_id, "paid_quest_rerolls", 1)
		GameServer.broadcast_leaderboard()
	else:
		NetAPI.rpc_id(peer_id, "notify_daily_quest_result", false, "Need %d coins for another reroll." % REROLL_COST)
		return
	_put_quest(player_id, day, slot, _roll_quest())
	NetAPI.rpc_id(peer_id, "notify_daily_quest_result", true, "Fresh page from the Harbor Ledger.")
	_send_quests(peer_id, session)

func handle_claim(peer_id: int, slot: int) -> void:
	var session := _at_harbor(peer_id)
	if session == null or slot < 0 or slot > 2: return
	var db = _db(); var player_id := _player_id(session.username); var day := _quest_day(player_id)
	if db == null or player_id < 0: return
	db.query_with_bindings("SELECT progress, target, reward, difficulty, claimed FROM daily_quests WHERE player_id = ? AND day_key = ? AND slot = ?", [player_id, day, slot])
	if db.query_result.is_empty() or int(db.query_result[0].claimed) != 0 or int(db.query_result[0].progress) < int(db.query_result[0].target):
		NetAPI.rpc_id(peer_id, "notify_daily_quest_result", false, "That ledger line is not ready to pay.")
		return
	var reward := int(db.query_result[0].reward)
	var difficulty := str(db.query_result[0].difficulty)
	db.query_with_bindings("UPDATE daily_quests SET claimed = 1 WHERE player_id = ? AND day_key = ? AND slot = ?", [player_id, day, slot])
	db.query_with_bindings("UPDATE daily_quest_state SET reset_at = ? WHERE player_id = ? AND day_key = ? AND reset_at = 0", [int(Time.get_unix_time_from_system()) + QUEST_RESET_SECONDS, player_id, day])
	session.coins += reward
	db.query_with_bindings("UPDATE players SET coins = ? WHERE id = ?", [session.coins, player_id])
	db.query_with_bindings("INSERT INTO player_career_stats (player_id, total_gold_earned, highest_balance) VALUES (?, ?, ?) ON CONFLICT(player_id) DO UPDATE SET total_gold_earned = total_gold_earned + excluded.total_gold_earned, highest_balance = MAX(highest_balance, excluded.highest_balance)", [player_id, reward, session.coins])
	_increment_by_id(player_id, "quest_gold_earned", reward)
	_increment_by_id(player_id, "quests_completed", 1)
	if difficulty == "Legendary":
		_increment_by_id(player_id, "legendary_quests_completed", 1)
	GameServer.broadcast_leaderboard()
	NetAPI.rpc_id(peer_id, "notify_coin_balance", session.coins)
	NetAPI.rpc_id(peer_id, "notify_daily_quest_result", true, "+%d gold from the Harbor Ledger." % reward)
	_send_quests(peer_id, session)

func record_fish_catch(session: PlayerSession, fish_id: String, earned: int, elapsed_ms: int, measurement: float, measurement_unit: String) -> bool:
	var db = _db(); var player_id := _player_id(session.username)
	if db == null or player_id < 0: return false
	var record := false
	if measurement_unit == "in":
		db.query_with_bindings("SELECT best_measurement FROM player_fish_stats WHERE player_id = ? AND fish_id = ?", [player_id, fish_id])
		record = db.query_result.is_empty() or measurement > float(db.query_result[0].best_measurement)
	db.query_with_bindings("INSERT INTO player_fish_stats (player_id, fish_id, caught_count, best_measurement) VALUES (?, ?, 1, ?) ON CONFLICT(player_id, fish_id) DO UPDATE SET caught_count = caught_count + 1, best_measurement = MAX(best_measurement, excluded.best_measurement)", [player_id, fish_id, measurement])
	db.query_with_bindings("INSERT INTO player_catch_log (player_id, fish_id, earned, measurement, measurement_unit, caught_at) VALUES (?, ?, ?, ?, ?, ?)", [player_id, fish_id, earned, measurement, measurement_unit, int(Time.get_unix_time_from_system())])
	var fish := ItemRegistry.get_item(fish_id) as FishData
	db.query_with_bindings("INSERT INTO player_career_stats (player_id, fish_caught, total_gold_earned, highest_balance, highest_catch_value, treasure_found, junk_caught, rare_catches, legendary_catches) VALUES (?, 1, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(player_id) DO UPDATE SET fish_caught = fish_caught + 1, total_gold_earned = total_gold_earned + excluded.total_gold_earned, highest_balance = MAX(highest_balance, excluded.highest_balance), highest_catch_value = MAX(highest_catch_value, excluded.highest_catch_value), treasure_found = treasure_found + excluded.treasure_found, junk_caught = junk_caught + excluded.junk_caught, rare_catches = rare_catches + excluded.rare_catches, legendary_catches = legendary_catches + excluded.legendary_catches", [player_id, earned, session.coins, earned, 1 if fish_id == "legendary_chest" or fish_id == "legendary_key" else 0, 1 if fish_id.begins_with("junk_") else 0, 1 if fish and fish.rarity == "rare" else 0, 1 if fish and fish.rarity == "legendary" else 0])
	db.query_with_bindings("UPDATE player_career_stats SET fastest_catch_ms = CASE WHEN fastest_catch_ms = 0 THEN ? ELSE MIN(fastest_catch_ms, ?) END WHERE player_id = ?", [elapsed_ms, elapsed_ms, player_id])
	if measurement_unit == "in": db.query_with_bindings("UPDATE player_career_stats SET biggest_fish_length = MAX(biggest_fish_length, ?) WHERE player_id = ?", [measurement, player_id])
	if measurement_unit == "lb": db.query_with_bindings("UPDATE player_career_stats SET heaviest_junk = MAX(heaviest_junk, ?) WHERE player_id = ?", [measurement, player_id])
	_update_fishing_streak(session, true)
	_progress(player_id, "catch_fish", fish_id, 1)
	return record

func record_line_cast(session: PlayerSession, perfect: bool) -> void:
	_increment(session, "lines_cast", 1)
	if perfect: _increment(session, "perfect_casts", 1)

func record_fish_got_away(session: PlayerSession, fish_id: String) -> void:
	var db = _db(); var player_id := _player_id(session.username)
	if db == null or player_id < 0: return
	db.query_with_bindings("INSERT INTO player_fish_stats (player_id, fish_id, got_away_count) VALUES (?, ?, 1) ON CONFLICT(player_id, fish_id) DO UPDATE SET got_away_count = got_away_count + 1", [player_id, fish_id])
	_increment(session, "fish_got_away", 1)
	_update_fishing_streak(session, false)

func record_gear_use(session: PlayerSession, item_id: String) -> void:
	if item_id.is_empty(): return
	var db = _db(); var player_id := _player_id(session.username)
	if db == null or player_id < 0: return
	db.query_with_bindings("INSERT INTO player_gear_stats (player_id, item_id, uses) VALUES (?, ?, 1) ON CONFLICT(player_id, item_id) DO UPDATE SET uses = uses + 1", [player_id, item_id])

func record_hand_played(session: PlayerSession) -> void:
	_increment(session, "hands_played", 1)

func record_chat_message(session: PlayerSession) -> void:
	_increment(session, "chat_messages", 1)

func record_chat_received(session: PlayerSession) -> void:
	_increment(session, "chat_messages_received", 1)

func record_shop_purchase(session: PlayerSession, cost: int, skin: bool = false) -> void:
	_increment(session, "shop_spent", cost)
	_increment(session, "items_bought", 1)
	_increment(session, "total_gold_spent", cost)
	if skin:
		_increment(session, "skins_purchased", 1)

func record_time_played(session: PlayerSession, milliseconds: int) -> void:
	_increment(session, "time_played_seconds", maxi(0, milliseconds / 1000))

func record_blackjack_result(session: PlayerSession, won: int, lost: int, bet: int, doubled: bool, outcome: String) -> void:
	var db = _db(); var player_id := _player_id(session.username)
	if db == null or player_id < 0: return
	db.query_with_bindings("INSERT INTO player_career_stats (player_id, casino_won, casino_lost, hands_won, hands_lost, double_downs, double_downs_won, biggest_win, biggest_loss) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(player_id) DO UPDATE SET casino_won = casino_won + excluded.casino_won, casino_lost = casino_lost + excluded.casino_lost, hands_won = hands_won + excluded.hands_won, hands_lost = hands_lost + excluded.hands_lost, double_downs = double_downs + excluded.double_downs, double_downs_won = double_downs_won + excluded.double_downs_won, biggest_win = MAX(biggest_win, excluded.biggest_win), biggest_loss = MAX(biggest_loss, excluded.biggest_loss)", [player_id, won, lost, 1 if won > 0 else 0, 1 if lost > 0 else 0, 1 if doubled else 0, 1 if doubled and won > 0 else 0, won, lost])
	if won > 0:
		_progress(player_id, "blackjack_hand", "", won)
		_progress(player_id, "casino_winnings", "", won)
	db.query_with_bindings("UPDATE player_career_stats SET total_wagered = total_wagered + ?, total_gold_earned = total_gold_earned + ?, total_gold_spent = total_gold_spent + ?, highest_balance = MAX(highest_balance, ?), blackjacks = blackjacks + ?, pushes = pushes + ?, busts = busts + ? WHERE player_id = ?", [bet, won, lost, session.coins, 1 if outcome == "win" and won * 2 == bet * 3 else 0, 1 if outcome == "push" else 0, 1 if outcome == "bust" else 0, player_id])
	if won > 0:
		db.query_with_bindings("UPDATE player_career_stats SET current_win_streak = current_win_streak + 1, current_loss_streak = 0, longest_win_streak = MAX(longest_win_streak, current_win_streak + 1) WHERE player_id = ?", [player_id])
	else:
		db.query_with_bindings("UPDATE player_career_stats SET current_loss_streak = current_loss_streak + 1, current_win_streak = 0, longest_loss_streak = MAX(longest_loss_streak, current_loss_streak + 1) WHERE player_id = ?", [player_id])

func record_mail(session: PlayerSession, recipient: String) -> void:
	_increment(session, "letters_sent", 1)
	var recipient_id := _player_id(recipient)
	if recipient_id < 0: return
	var db = _db(); var sender_id := _player_id(session.username)
	if db == null or sender_id < 0: return
	_increment_by_id(recipient_id, "letters_received", 1)
	for pair in [[sender_id, recipient_id], [recipient_id, sender_id]]:
		db.query_with_bindings("INSERT OR IGNORE INTO player_encounters (player_id, other_player_id) VALUES (?, ?)", pair)
	for id in [sender_id, recipient_id]:
		db.query_with_bindings("SELECT COUNT(*) AS total FROM player_encounters WHERE player_id = ?", [id])
		db.query_with_bindings("UPDATE player_career_stats SET unique_players_encountered = ? WHERE player_id = ?", [int(db.query_result[0].total), id])

func _update_fishing_streak(session: PlayerSession, caught: bool) -> void:
	var db = _db(); var player_id := _player_id(session.username)
	if db == null or player_id < 0: return
	if caught:
		db.query_with_bindings("UPDATE player_career_stats SET current_fish_streak = current_fish_streak + 1, longest_fish_streak = MAX(longest_fish_streak, current_fish_streak + 1) WHERE player_id = ?", [player_id])
	else:
		db.query_with_bindings("UPDATE player_career_stats SET current_fish_streak = 0 WHERE player_id = ?", [player_id])

func _send_quests(peer_id: int, session: PlayerSession) -> void:
	var db = _db(); var player_id := _player_id(session.username); var day := _quest_day(player_id)
	if db == null or player_id < 0: return
	_ensure_day(player_id, day)
	db.query_with_bindings("SELECT slot, kind, fish_id, target, progress, reward, difficulty, claimed FROM daily_quests WHERE player_id = ? AND day_key = ? ORDER BY slot", [player_id, day])
	var quests: Array = db.query_result.duplicate()
	db.query_with_bindings("SELECT free_rerolls_used, reset_at FROM daily_quest_state WHERE player_id = ? AND day_key = ?", [player_id, day])
	var used := int(db.query_result[0].free_rerolls_used) if not db.query_result.is_empty() else 0
	var reset_at := int(db.query_result[0].reset_at) if not db.query_result.is_empty() else 0
	NetAPI.rpc_id(peer_id, "notify_daily_quests", {"quests": quests, "free_rerolls_left": maxi(0, FREE_REROLLS - used), "reroll_cost": REROLL_COST, "coins": session.coins, "reset_at": reset_at})

func _ensure_day(player_id: int, day: String) -> void:
	var db = _db()
	db.query_with_bindings("INSERT OR IGNORE INTO daily_quest_state (player_id, day_key) VALUES (?, ?)", [player_id, day])
	db.query_with_bindings("SELECT COUNT(*) AS total FROM daily_quests WHERE player_id = ? AND day_key = ?", [player_id, day])
	var count := int(db.query_result[0].total) if not db.query_result.is_empty() else 0
	for slot in range(count, 3): _put_quest(player_id, day, slot, _roll_quest())

func _put_quest(player_id: int, day: String, slot: int, quest: Dictionary) -> void:
	_db().query_with_bindings("INSERT OR REPLACE INTO daily_quests (player_id, day_key, slot, kind, fish_id, target, progress, reward, difficulty, claimed) VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?, 0)", [player_id, day, slot, quest.kind, quest.fish_id, quest.target, quest.reward, quest.difficulty])

func _roll_quest() -> Dictionary:
	var roll := randi_range(1, 100); var total := 0; var tier: Dictionary = DIFFICULTIES[0]
	for candidate: Dictionary in DIFFICULTIES:
		total += int(candidate.weight)
		if roll <= total: tier = candidate; break
	var kinds: Array[String] = ["catch_fish", "blackjack_hand", "casino_winnings"]
	var kind: String = kinds.pick_random()
	var fish_id: String = ""
	if kind == "catch_fish":
		var rarity := "common" if tier.name == "Easy" else "uncommon" if tier.name == "Medium" else "rare" if tier.name == "Hard" else "legendary"
		var choices: Array = ItemRegistry.fish.values().filter(func(f: FishData) -> bool: return f.rarity == rarity and not f.id.begins_with("junk_")).map(func(f: FishData) -> String: return f.id)
		fish_id = str(choices.pick_random()) if not choices.is_empty() else "common_perch"
	return {"kind": kind, "fish_id": fish_id, "target": int(tier.fish if kind == "catch_fish" else tier.hand if kind == "blackjack_hand" else tier.casino), "reward": int(tier.reward), "difficulty": str(tier.name)}

func _progress(player_id: int, kind: String, fish_id: String, amount: int) -> void:
	var db = _db()
	if db == null: return
	var day := _quest_day(player_id)
	_ensure_day(player_id, day)
	var sql := "UPDATE daily_quests SET progress = MIN(target, progress + ?) WHERE player_id = ? AND day_key = ? AND kind = ? AND claimed = 0"
	var bindings: Array = [amount, player_id, day, kind]
	if kind == "catch_fish": sql += " AND fish_id = ?"; bindings.append(fish_id)
	db.query_with_bindings(sql, bindings)

func _increment(session: PlayerSession, column: String, amount: int) -> void:
	var db = _db(); var player_id := _player_id(session.username)
	if db == null or player_id < 0: return
	_increment_by_id(player_id, column, amount)

func _increment_by_id(player_id: int, column: String, amount: int) -> void:
	var db = _db()
	if db == null: return
	db.query_with_bindings("INSERT INTO player_career_stats (player_id, %s) VALUES (?, ?) ON CONFLICT(player_id) DO UPDATE SET %s = %s + excluded.%s" % [column, column, column, column], [player_id, amount])

func _at_harbor(peer_id: int) -> PlayerSession:
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null: return null
	NetAPI._refresh_peer_zone(peer_id)
	return session if session.current_zone == "HarborMasterZone" else null

func _db():
	var auth = GameServer.get_node_or_null("AuthServer")
	return auth._db if auth and auth._db else null

func _player_id(username: String) -> int:
	var db = _db()
	if db == null: return -1
	db.query_with_bindings("SELECT id FROM players WHERE username = ?", [username])
	return int(db.query_result[0].id) if not db.query_result.is_empty() else -1

func _day_key() -> String:
	return Time.get_datetime_string_from_system(false).left(10)

func _quest_day(player_id: int) -> String:
	var db = _db()
	if db == null:
		return _day_key()
	db.query_with_bindings("SELECT day_key, reset_at FROM daily_quest_state WHERE player_id = ? ORDER BY day_key DESC LIMIT 1", [player_id])
	if not db.query_result.is_empty() and int(db.query_result[0].reset_at) > int(Time.get_unix_time_from_system()):
		return str(db.query_result[0].day_key)
	return _day_key()
