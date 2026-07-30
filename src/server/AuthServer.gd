extends Node

var _db = null

func _ready() -> void:
	if not ClassDB.class_exists("SQLite"):
		push_error("AuthServer: godot-sqlite not installed. See addons/godot-sqlite/INSTALL.md")
		return
	_db = ClassDB.instantiate("SQLite")
	# Use a path relative to the executable when running as dedicated server
	# so the DB lands in the Docker volume mount (./data:/app/data).
	# In editor/client mode fall back to Godot's user data dir.
	if OS.has_feature("dedicated_server"):
		_db.path = "data/players"
	else:
		_db.path = "user://players"
	_db.verbosity_level = 0
	if not _db.open_db():
		push_error("AuthServer: failed to open database")
		return
	_init_schema()
	print("AuthServer: database ready")

func _init_schema() -> void:
	_db.query("""
		CREATE TABLE IF NOT EXISTS players (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			username TEXT UNIQUE NOT NULL,
			password_hash TEXT NOT NULL,
			salt TEXT NOT NULL,
			coins INTEGER DEFAULT 50,
			created_at INTEGER,
			last_login INTEGER
		)
	""")
	_db.query("""
		CREATE TABLE IF NOT EXISTS inventory (
			player_id INTEGER REFERENCES players(id),
			item_id TEXT NOT NULL,
			quantity INTEGER DEFAULT 1,
			UNIQUE(player_id, item_id)
		)
	""")
	_db.query("""
		CREATE TABLE IF NOT EXISTS blackjack_shoes (
			commitment TEXT PRIMARY KEY,
			seed TEXT NOT NULL,
			nonce TEXT NOT NULL,
			dealt_cards TEXT NOT NULL DEFAULT '[]',
			audit_log TEXT NOT NULL DEFAULT '[]',
			created_at INTEGER NOT NULL,
			revealed_at INTEGER
		)
	""")
	_db.query("""
		CREATE TABLE IF NOT EXISTS mailbox_messages (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			sender_username TEXT NOT NULL,
			recipient_username TEXT NOT NULL,
			body TEXT NOT NULL,
			sent_at INTEGER NOT NULL
		)
	""")
	_db.query("""
		CREATE TABLE IF NOT EXISTS player_fish_stats (
			player_id INTEGER NOT NULL,
			fish_id TEXT NOT NULL,
			caught_count INTEGER NOT NULL DEFAULT 0,
			got_away_count INTEGER NOT NULL DEFAULT 0,
			best_measurement REAL NOT NULL DEFAULT 0,
			PRIMARY KEY(player_id, fish_id)
		)
	""")
	_ensure_fish_stat_column("got_away_count", "INTEGER NOT NULL DEFAULT 0")
	_ensure_fish_stat_column("best_measurement", "REAL NOT NULL DEFAULT 0")
	_db.query("""
		CREATE TABLE IF NOT EXISTS player_career_stats (
			player_id INTEGER PRIMARY KEY,
			casino_won INTEGER NOT NULL DEFAULT 0,
			casino_lost INTEGER NOT NULL DEFAULT 0,
			fish_caught INTEGER NOT NULL DEFAULT 0,
			lines_cast INTEGER NOT NULL DEFAULT 0,
			fish_got_away INTEGER NOT NULL DEFAULT 0,
			perfect_casts INTEGER NOT NULL DEFAULT 0,
			hands_played INTEGER NOT NULL DEFAULT 0,
			hands_won INTEGER NOT NULL DEFAULT 0,
			hands_lost INTEGER NOT NULL DEFAULT 0,
			double_downs INTEGER NOT NULL DEFAULT 0,
			double_downs_won INTEGER NOT NULL DEFAULT 0,
			biggest_win INTEGER NOT NULL DEFAULT 0,
			biggest_loss INTEGER NOT NULL DEFAULT 0,
			chat_messages INTEGER NOT NULL DEFAULT 0,
			shop_spent INTEGER NOT NULL DEFAULT 0,
			items_bought INTEGER NOT NULL DEFAULT 0,
			time_played_seconds INTEGER NOT NULL DEFAULT 0
		)
	""")
	_db.query("CREATE TABLE IF NOT EXISTS player_gear_stats (player_id INTEGER NOT NULL, item_id TEXT NOT NULL, uses INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(player_id, item_id))")
	_db.query("CREATE TABLE IF NOT EXISTS player_login_days (player_id INTEGER NOT NULL, day_key TEXT NOT NULL, PRIMARY KEY(player_id, day_key))")
	_db.query("CREATE TABLE IF NOT EXISTS player_encounters (player_id INTEGER NOT NULL, other_player_id INTEGER NOT NULL, PRIMARY KEY(player_id, other_player_id))")
	_db.query("CREATE TABLE IF NOT EXISTS player_catch_log (id INTEGER PRIMARY KEY AUTOINCREMENT, player_id INTEGER NOT NULL, fish_id TEXT NOT NULL, earned INTEGER NOT NULL, measurement REAL NOT NULL DEFAULT 0, measurement_unit TEXT NOT NULL DEFAULT '', caught_at INTEGER NOT NULL)")
	for column in ["lines_cast INTEGER NOT NULL DEFAULT 0", "fish_got_away INTEGER NOT NULL DEFAULT 0", "perfect_casts INTEGER NOT NULL DEFAULT 0", "hands_played INTEGER NOT NULL DEFAULT 0", "hands_won INTEGER NOT NULL DEFAULT 0", "hands_lost INTEGER NOT NULL DEFAULT 0", "double_downs INTEGER NOT NULL DEFAULT 0", "double_downs_won INTEGER NOT NULL DEFAULT 0", "biggest_win INTEGER NOT NULL DEFAULT 0", "biggest_loss INTEGER NOT NULL DEFAULT 0", "chat_messages INTEGER NOT NULL DEFAULT 0", "chat_messages_received INTEGER NOT NULL DEFAULT 0", "shop_spent INTEGER NOT NULL DEFAULT 0", "items_bought INTEGER NOT NULL DEFAULT 0", "time_played_seconds INTEGER NOT NULL DEFAULT 0", "total_gold_earned INTEGER NOT NULL DEFAULT 0", "total_gold_spent INTEGER NOT NULL DEFAULT 0", "highest_balance INTEGER NOT NULL DEFAULT 0", "skins_purchased INTEGER NOT NULL DEFAULT 0", "treasure_found INTEGER NOT NULL DEFAULT 0", "junk_caught INTEGER NOT NULL DEFAULT 0", "rare_catches INTEGER NOT NULL DEFAULT 0", "legendary_catches INTEGER NOT NULL DEFAULT 0", "highest_catch_value INTEGER NOT NULL DEFAULT 0", "biggest_fish_length REAL NOT NULL DEFAULT 0", "heaviest_junk REAL NOT NULL DEFAULT 0", "fastest_catch_ms INTEGER NOT NULL DEFAULT 0", "blackjacks INTEGER NOT NULL DEFAULT 0", "pushes INTEGER NOT NULL DEFAULT 0", "busts INTEGER NOT NULL DEFAULT 0", "total_wagered INTEGER NOT NULL DEFAULT 0", "longest_win_streak INTEGER NOT NULL DEFAULT 0", "longest_loss_streak INTEGER NOT NULL DEFAULT 0", "current_win_streak INTEGER NOT NULL DEFAULT 0", "current_loss_streak INTEGER NOT NULL DEFAULT 0", "current_fish_streak INTEGER NOT NULL DEFAULT 0", "longest_fish_streak INTEGER NOT NULL DEFAULT 0", "longest_login_streak INTEGER NOT NULL DEFAULT 0", "letters_sent INTEGER NOT NULL DEFAULT 0", "letters_received INTEGER NOT NULL DEFAULT 0", "unique_players_encountered INTEGER NOT NULL DEFAULT 0", "derbies_entered INTEGER NOT NULL DEFAULT 0", "derbies_won INTEGER NOT NULL DEFAULT 0", "best_derby_place INTEGER NOT NULL DEFAULT 0", "derby_fish_caught INTEGER NOT NULL DEFAULT 0"]:
		var parts: PackedStringArray = column.split(" ", false, 1)
		_ensure_career_stat_column(parts[0], parts[1])
	_db.query("""
		CREATE TABLE IF NOT EXISTS daily_quest_state (
			player_id INTEGER NOT NULL,
			day_key TEXT NOT NULL,
			free_rerolls_used INTEGER NOT NULL DEFAULT 0,
			reset_at INTEGER NOT NULL DEFAULT 0,
			PRIMARY KEY(player_id, day_key)
		)
	""")
	_ensure_daily_quest_state_column("reset_at", "INTEGER NOT NULL DEFAULT 0")
	_db.query("""
		CREATE TABLE IF NOT EXISTS daily_quests (
			player_id INTEGER NOT NULL,
			day_key TEXT NOT NULL,
			slot INTEGER NOT NULL,
			kind TEXT NOT NULL,
			fish_id TEXT NOT NULL DEFAULT '',
			target INTEGER NOT NULL,
			progress INTEGER NOT NULL DEFAULT 0,
			reward INTEGER NOT NULL,
			difficulty TEXT NOT NULL,
			claimed INTEGER NOT NULL DEFAULT 0,
			PRIMARY KEY(player_id, day_key, slot)
		)
	""")
	_ensure_blackjack_shoe_column("audit_log", "TEXT NOT NULL DEFAULT '[]'")
	_ensure_player_column("equipped_rod_id", "TEXT DEFAULT ''")
	_ensure_player_column("equipped_skin_id", "TEXT DEFAULT ''")
	_ensure_player_column("equipped_bobber_id", "TEXT DEFAULT ''")
	_ensure_player_column("equipped_bait_id", "TEXT DEFAULT ''")
	_ensure_player_column("equipped_tackle_id", "TEXT DEFAULT ''")
	_ensure_player_column("hook_durability", "INTEGER DEFAULT 0")
	_ensure_player_column("hook_durabilities", "TEXT DEFAULT '{}'")

# ── Public API ────────────────────────────────────────────────────────────────

func handle_login(peer_id: int, username: String, pw_hash: String) -> void:
	push_warning("AuthServer: login attempt peer=%d username=%s" % [peer_id, username])
	if _db == null:
		NetAPI.rpc_id(peer_id, "notify_login", false, "Server database unavailable.", 0)
		return
	var session := GameServer.get_session(peer_id)
	if session == null or session.authenticated:
		NetAPI.rpc_id(peer_id, "notify_login", false, "Already logged in.", 0)
		return

	_db.query_with_bindings("SELECT * FROM players WHERE username = ?", [username])
	var rows: Array = _db.query_result
	if rows.is_empty():
		push_warning("AuthServer: login failed unknown username=%s" % username)
		NetAPI.rpc_id(peer_id, "notify_login", false, "Unknown username.", 0)
		return

	var row: Dictionary = rows[0]
	if _hash_salted(pw_hash, row.salt) != row.password_hash:
		push_warning("AuthServer: login failed bad password username=%s" % username)
		NetAPI.rpc_id(peer_id, "notify_login", false, "Incorrect password.", 0)
		return
	if GameServer.is_username_authenticated(username):
		NetAPI.rpc_id(peer_id, "notify_login", false, "This account is already logged in.", 0)
		return

	_db.query_with_bindings(
		"UPDATE players SET last_login = ? WHERE id = ?",
		[int(Time.get_unix_time_from_system()), row.id]
	)

	session.authenticated = true
	session.username = username
	session.coins = int(row.coins)
	_record_login_day(int(row.id))
	_load_equipped(session, int(row.id))

	# Send full inventory before login confirmation
	_db.query_with_bindings(
		"SELECT item_id, quantity FROM inventory WHERE player_id = ?", [int(row.id)]
	)
	var inventory := {}
	for inv_row in _db.query_result:
		inventory[inv_row.item_id] = int(inv_row.quantity)
	NetAPI.rpc_id(peer_id, "notify_inventory_loaded", inventory)
	NetAPI.rpc_id(peer_id, "notify_cosmetics_loaded", session.equipped_skin_id, session.equipped_bobber_id)
	# Send initial hook durability
	if session and not session.equipped_tackle_id.is_empty():
		var tackle := ItemRegistry.get_item(session.equipped_tackle_id) as TackleData
		if tackle:
			NetAPI.rpc_id(peer_id, "notify_equipment_loaded", session.equipped_rod_id, session.equipped_bait_id, session.equipped_tackle_id, session.hook_durability, tackle.durability)
		else:
			push_warning("AuthServer: equipped tackle not found peer=%d tackle=%s items_loaded=%d" % [peer_id, session.equipped_tackle_id, ItemRegistry.items.size()])
			NetAPI.rpc_id(peer_id, "notify_equipment_loaded", session.equipped_rod_id, session.equipped_bait_id, session.equipped_tackle_id, session.hook_durability, 0)
	elif session:
		NetAPI.rpc_id(peer_id, "notify_equipment_loaded", session.equipped_rod_id, session.equipped_bait_id, session.equipped_tackle_id, 0, 0)
	NetAPI.rpc_id(peer_id, "notify_login", true, "", int(row.coins))
	push_warning("AuthServer: login ok peer=%d username=%s owned=%s equipped=[%s,%s,%s] hook=%d registry_items=%d" % [
		peer_id,
		username,
		str(session.owned_items if session else {}),
		session.equipped_rod_id if session else "",
		session.equipped_bait_id if session else "",
		session.equipped_tackle_id if session else "",
		session.hook_durability if session else 0,
		ItemRegistry.items.size(),
	])

func handle_register(peer_id: int, username: String, pw_hash: String) -> void:
	push_warning("AuthServer: register attempt peer=%d username=%s" % [peer_id, username])
	if _db == null:
		NetAPI.rpc_id(peer_id, "notify_register", false, "Server database unavailable.")
		return

	if username.length() < 3 or username.length() > 24:
		NetAPI.rpc_id(peer_id, "notify_register", false, "Username must be 3–24 characters.")
		return

	var salt := _generate_salt()
	var now := int(Time.get_unix_time_from_system())
	var ok: bool = _db.query_with_bindings(
		"INSERT INTO players (username, password_hash, salt, coins, created_at, last_login) VALUES (?, ?, ?, ?, ?, ?)",
		[username, _hash_salted(pw_hash, salt), salt, GameServer.STARTER_COINS, now, now]
	)

	if ok:
		_ensure_starter_items(username, -1, true)
		NetAPI.rpc_id(peer_id, "notify_register", true, "")
		push_warning("AuthServer: register ok peer=%d username=%s" % [peer_id, username])
	else:
		push_warning("AuthServer: register failed duplicate username=%s" % username)
		NetAPI.rpc_id(peer_id, "notify_register", false, "Username already taken.")

func reset_password(username: String, new_password: String) -> bool:
	if _db == null:
		push_error("AuthServer: cannot reset password; database unavailable")
		return false
	if username.strip_edges().is_empty() or new_password.is_empty():
		push_error("AuthServer: reset password requires username and password")
		return false

	_db.query_with_bindings("SELECT id FROM players WHERE username = ?", [username])
	if _db.query_result.is_empty():
		push_error("AuthServer: reset password failed; user '%s' not found" % username)
		return false

	var salt := _generate_salt()
	var ok: bool = _db.query_with_bindings(
		"UPDATE players SET password_hash = ?, salt = ? WHERE username = ?",
		[_hash_salted(_hash_plain_password(new_password), salt), salt, username]
	)
	if ok:
		print("AuthServer: password reset for user '%s'" % username)
	else:
		push_error("AuthServer: reset password update failed for user '%s'" % username)
	return ok

# ── Helpers ───────────────────────────────────────────────────────────────────

func _ensure_starter_items(username: String, player_id: int = -1, force_equipment: bool = false) -> void:
	if player_id <= 0:
		_db.query_with_bindings("SELECT id FROM players WHERE username = ?", [username])
		if _db.query_result.is_empty():
			return
		player_id = int(_db.query_result[0].id)

	_db.query_with_bindings("""
		DELETE FROM inventory
		WHERE player_id = ?
			AND item_id IN ('STARTER_ROD_ID', 'STARTER_BAIT_ID', 'STARTER_TACKLE_ID')
	""", [player_id])
	var starter_items := GameServer.get_starter_items()
	for item_id in starter_items:
		_db.query_with_bindings("""
			INSERT INTO inventory (player_id, item_id, quantity)
			VALUES (?, ?, ?)
			ON CONFLICT(player_id, item_id) DO UPDATE SET quantity = MAX(quantity, excluded.quantity)
		""", [player_id, item_id, int(starter_items[item_id])])

	if force_equipment:
		_set_starter_equipment(username)
	else:
		_ensure_usable_equipment(username, player_id)

func _set_starter_equipment(username: String) -> void:
	_db.query_with_bindings("""
		UPDATE players
		SET equipped_rod_id = ?,
			equipped_bait_id = ?,
			equipped_tackle_id = ?,
			hook_durability = ?
		WHERE username = ?
	""", [
		GameServer.STARTER_ROD_ID,
		GameServer.STARTER_BAIT_ID,
		GameServer.STARTER_TACKLE_ID,
		GameServer.get_starter_hook_durability(),
		username,
	])

func _ensure_usable_equipment(username: String, player_id: int) -> void:
	_db.query_with_bindings(
		"SELECT equipped_rod_id, equipped_bait_id, equipped_tackle_id, hook_durability, hook_durabilities FROM players WHERE id = ?",
		[player_id]
	)
	if _db.query_result.is_empty():
		return
	var row: Dictionary = _db.query_result[0]
	var has_rod := _has_owned_slot_item(player_id, str(row.equipped_rod_id), "rod")
	var has_bait := _has_owned_slot_item(player_id, str(row.equipped_bait_id), "bait")
	var has_tackle := _has_owned_slot_item(player_id, str(row.equipped_tackle_id), "tackle")
	if has_rod and has_bait and has_tackle:
		return
	push_warning("AuthServer: repairing starter equipment username=%s" % username)
	_db.query_with_bindings("""
		UPDATE players
		SET equipped_rod_id = ?,
			equipped_bait_id = ?,
			equipped_tackle_id = ?,
			hook_durability = CASE WHEN hook_durability > 0 THEN hook_durability ELSE ? END
		WHERE id = ?
	""", [
		str(row.equipped_rod_id) if has_rod else GameServer.STARTER_ROD_ID,
		str(row.equipped_bait_id) if has_bait else GameServer.STARTER_BAIT_ID,
		str(row.equipped_tackle_id) if has_tackle else GameServer.STARTER_TACKLE_ID,
		GameServer.get_starter_hook_durability(),
		player_id,
	])

func _has_owned_slot_item(player_id: int, item_id: String, slot: String) -> bool:
	if not _has_owned_item(player_id, item_id):
		return false
	return _item_matches_slot(ItemRegistry.get_item(item_id), slot)

func _has_owned_item(player_id: int, item_id: String) -> bool:
	if item_id.is_empty() or ItemRegistry.get_item(item_id) == null:
		return false
	_db.query_with_bindings(
		"SELECT quantity FROM inventory WHERE player_id = ? AND item_id = ?",
		[player_id, item_id]
	)
	return not _db.query_result.is_empty() and int(_db.query_result[0].quantity) > 0

func _load_equipped(session: PlayerSession, player_id: int) -> void:
	_db.query_with_bindings(
		"SELECT item_id, quantity FROM inventory WHERE player_id = ?", [player_id]
	)
	var first_rod := ""
	var first_bait := ""
	var first_tackle := ""
	for inv_row in _db.query_result:
		var item_id: String = inv_row.item_id
		var qty: int = int(inv_row.quantity)
		if qty > 0:
			session.owned_items[item_id] = qty
			var item := ItemRegistry.get_item(item_id)
			if item is RodData and first_rod.is_empty():
				first_rod = item_id
			elif item is BaitData and first_bait.is_empty():
				first_bait = item_id
			elif item is TackleData and first_tackle.is_empty():
				first_tackle = item_id
	_db.query_with_bindings(
		"SELECT equipped_rod_id, equipped_bait_id, equipped_tackle_id, equipped_skin_id, equipped_bobber_id, hook_durability, hook_durabilities FROM players WHERE id = ?",
		[player_id]
	)
	if not _db.query_result.is_empty():
		var row: Dictionary = _db.query_result[0]
		var rod_id := str(row.equipped_rod_id)
		var bait_id := str(row.equipped_bait_id)
		var tackle_id := str(row.equipped_tackle_id)
		var skin_id := str(row.equipped_skin_id)
		var bobber_id := str(row.equipped_bobber_id)
		var saved_durabilities = JSON.parse_string(str(row.hook_durabilities))
		if saved_durabilities is Dictionary:
			session.hook_durabilities = saved_durabilities
		session.equipped_rod_id = rod_id if _is_owned_slot_item(session, rod_id, "rod") else first_rod
		session.equipped_bait_id = bait_id if _is_owned_slot_item(session, bait_id, "bait") else first_bait
		session.equipped_tackle_id = tackle_id if _is_owned_slot_item(session, tackle_id, "tackle") else first_tackle
		session.equipped_skin_id = skin_id if _is_owned_cosmetic(session, skin_id, "skins") else ""
		session.equipped_bobber_id = bobber_id if _is_owned_cosmetic(session, bobber_id, "bobbers") else ""
		if not session.equipped_tackle_id.is_empty():
			var equipped_tackle := ItemRegistry.get_item(session.equipped_tackle_id) as TackleData
			if equipped_tackle:
				session.select_tackle(session.equipped_tackle_id, equipped_tackle.durability, int(row.hook_durability))
	else:
		session.equipped_rod_id = first_rod
		session.equipped_bait_id = first_bait
		session.equipped_tackle_id = first_tackle

	session.enforce_equipment_rules()
	save_equipment(session)

func _is_owned_slot_item(session: PlayerSession, item_id: String, slot: String) -> bool:
	return session.get_owned(item_id) > 0 and _item_matches_slot(ItemRegistry.get_item(item_id), slot)

func _is_owned_cosmetic(session: PlayerSession, item_id: String, category: String) -> bool:
	return session.get_owned(item_id) > 0 and str(CosmeticCatalog.get_item(item_id).get("category", "")) == category

func _item_matches_slot(item: ItemData, slot: String) -> bool:
	match slot:
		"rod":
			return item is RodData
		"bait":
			return item is BaitData
		"tackle":
			return item is TackleData
	return false

func save_equipment(session: PlayerSession) -> void:
	if _db == null:
		return
	_db.query_with_bindings("""
		UPDATE players
		SET equipped_rod_id = ?,
			equipped_bait_id = ?,
			equipped_tackle_id = ?,
			equipped_skin_id = ?,
			equipped_bobber_id = ?,
			hook_durability = ?,
			hook_durabilities = ?
		WHERE username = ?
	""", [
		session.equipped_rod_id,
		session.equipped_bait_id,
		session.equipped_tackle_id,
		session.equipped_skin_id,
		session.equipped_bobber_id,
		session.hook_durability,
		JSON.stringify(session.hook_durabilities),
		session.username,
	])

func _ensure_player_column(column_name: String, column_def: String) -> void:
	_db.query("PRAGMA table_info(players)")
	for row in _db.query_result:
		if str(row.name) == column_name:
			return
	_db.query("ALTER TABLE players ADD COLUMN %s %s" % [column_name, column_def])

func _ensure_blackjack_shoe_column(column_name: String, column_def: String) -> void:
	_db.query("PRAGMA table_info(blackjack_shoes)")
	for row in _db.query_result:
		if str(row.name) == column_name:
			return
	_db.query("ALTER TABLE blackjack_shoes ADD COLUMN %s %s" % [column_name, column_def])

func _ensure_daily_quest_state_column(column_name: String, column_def: String) -> void:
	_db.query("PRAGMA table_info(daily_quest_state)")
	for row in _db.query_result:
		if str(row.name) == column_name:
			return
	_db.query("ALTER TABLE daily_quest_state ADD COLUMN %s %s" % [column_name, column_def])

func _ensure_career_stat_column(column_name: String, column_def: String) -> void:
	_db.query("PRAGMA table_info(player_career_stats)")
	for row in _db.query_result:
		if str(row.name) == column_name:
			return
	_db.query("ALTER TABLE player_career_stats ADD COLUMN %s %s" % [column_name, column_def])

func _ensure_fish_stat_column(column_name: String, column_def: String) -> void:
	_db.query("PRAGMA table_info(player_fish_stats)")
	for row in _db.query_result:
		if str(row.name) == column_name:
			return
	_db.query("ALTER TABLE player_fish_stats ADD COLUMN %s %s" % [column_name, column_def])

func _record_login_day(player_id: int) -> void:
	_db.query_with_bindings("INSERT OR IGNORE INTO player_login_days (player_id, day_key) VALUES (?, ?)", [player_id, Time.get_datetime_string_from_system(false).left(10)])
	_db.query_with_bindings("SELECT day_key FROM player_login_days WHERE player_id = ? ORDER BY day_key DESC", [player_id])
	var streak := 0
	var expected := Time.get_unix_time_from_datetime_string(Time.get_datetime_string_from_system(false).left(10) + "T00:00:00")
	for row in _db.query_result:
		var timestamp := Time.get_unix_time_from_datetime_string(str(row.day_key) + "T00:00:00")
		if timestamp != expected: break
		streak += 1
		expected -= 86_400
	_db.query_with_bindings("INSERT INTO player_career_stats (player_id, longest_login_streak) VALUES (?, ?) ON CONFLICT(player_id) DO UPDATE SET longest_login_streak = MAX(longest_login_streak, excluded.longest_login_streak)", [player_id, streak])

func _generate_salt() -> String:
	var bytes := PackedByteArray()
	bytes.resize(16)
	for i in 16:
		bytes[i] = randi() % 256
	return bytes.hex_encode()

func _hash_salted(pw_hash: String, salt: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((pw_hash + salt).to_utf8_buffer())
	return ctx.finish().hex_encode()

func _hash_plain_password(password: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(password.to_utf8_buffer())
	return ctx.finish().hex_encode()
