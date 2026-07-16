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
	_ensure_player_column("equipped_rod_id", "TEXT DEFAULT ''")
	_ensure_player_column("equipped_bait_id", "TEXT DEFAULT ''")
	_ensure_player_column("equipped_tackle_id", "TEXT DEFAULT ''")
	_ensure_player_column("hook_durability", "INTEGER DEFAULT 0")

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
	_load_equipped(session, int(row.id))

	# Send full inventory before login confirmation
	_db.query_with_bindings(
		"SELECT item_id, quantity FROM inventory WHERE player_id = ?", [int(row.id)]
	)
	var inventory := {}
	for inv_row in _db.query_result:
		inventory[inv_row.item_id] = int(inv_row.quantity)
	NetAPI.rpc_id(peer_id, "notify_inventory_loaded", inventory)
	# Send initial hook durability
	if session and not session.equipped_tackle_id.is_empty():
		var tackle := ItemRegistry.get_item(session.equipped_tackle_id) as TackleData
		if tackle:
			if session.hook_durability == 0:
				session.hook_durability = tackle.durability
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
		"SELECT equipped_rod_id, equipped_bait_id, equipped_tackle_id, hook_durability FROM players WHERE id = ?",
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
		"SELECT equipped_rod_id, equipped_bait_id, equipped_tackle_id, hook_durability FROM players WHERE id = ?",
		[player_id]
	)
	if not _db.query_result.is_empty():
		var row: Dictionary = _db.query_result[0]
		var rod_id := str(row.equipped_rod_id)
		var bait_id := str(row.equipped_bait_id)
		var tackle_id := str(row.equipped_tackle_id)
		session.equipped_rod_id = rod_id if _is_owned_slot_item(session, rod_id, "rod") else first_rod
		session.equipped_bait_id = bait_id if _is_owned_slot_item(session, bait_id, "bait") else first_bait
		session.equipped_tackle_id = tackle_id if _is_owned_slot_item(session, tackle_id, "tackle") else first_tackle
		session.hook_durability = int(row.hook_durability)
	else:
		session.equipped_rod_id = first_rod
		session.equipped_bait_id = first_bait
		session.equipped_tackle_id = first_tackle

	if not session.equipped_tackle_id.is_empty():
		var tackle := ItemRegistry.get_item(session.equipped_tackle_id) as TackleData
		if tackle and session.hook_durability <= 0:
			session.hook_durability = tackle.durability
	session.enforce_equipment_rules()
	save_equipment(session)

func _is_owned_slot_item(session: PlayerSession, item_id: String, slot: String) -> bool:
	return session.get_owned(item_id) > 0 and _item_matches_slot(ItemRegistry.get_item(item_id), slot)

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
			hook_durability = ?
		WHERE username = ?
	""", [
		session.equipped_rod_id,
		session.equipped_bait_id,
		session.equipped_tackle_id,
		session.hook_durability,
		session.username,
	])

func _ensure_player_column(column_name: String, column_def: String) -> void:
	_db.query("PRAGMA table_info(players)")
	for row in _db.query_result:
		if str(row.name) == column_name:
			return
	_db.query("ALTER TABLE players ADD COLUMN %s %s" % [column_name, column_def])

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
