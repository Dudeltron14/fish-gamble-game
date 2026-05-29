extends Node

var _db = null

func _ready() -> void:
	if not ClassDB.class_exists("SQLite"):
		push_error("AuthServer: godot-sqlite not installed. See addons/godot-sqlite/INSTALL.md")
		return
	_db = ClassDB.instantiate("SQLite")
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

# ── Public API ────────────────────────────────────────────────────────────────

func handle_login(peer_id: int, username: String, pw_hash: String) -> void:
	if _db == null:
		NetAPI.rpc_id(peer_id, "notify_login", false, "Server database unavailable.", 0)
		return

	_db.query_with_bindings("SELECT * FROM players WHERE username = ?", [username])
	var rows: Array = _db.query_result
	if rows.is_empty():
		NetAPI.rpc_id(peer_id, "notify_login", false, "Unknown username.", 0)
		return

	var row: Dictionary = rows[0]
	if _hash_salted(pw_hash, row.salt) != row.password_hash:
		NetAPI.rpc_id(peer_id, "notify_login", false, "Incorrect password.", 0)
		return

	_db.query_with_bindings(
		"UPDATE players SET last_login = ? WHERE id = ?",
		[int(Time.get_unix_time_from_system()), row.id]
	)

	var session := GameServer.get_session(peer_id)
	if session:
		session.authenticated = true
		session.username = username
		session.coins = int(row.coins)

	NetAPI.rpc_id(peer_id, "notify_login", true, "", int(row.coins))

func handle_register(peer_id: int, username: String, pw_hash: String) -> void:
	if _db == null:
		NetAPI.rpc_id(peer_id, "notify_register", false, "Server database unavailable.")
		return

	if username.length() < 3 or username.length() > 24:
		NetAPI.rpc_id(peer_id, "notify_register", false, "Username must be 3–24 characters.")
		return

	var salt := _generate_salt()
	var now := int(Time.get_unix_time_from_system())
	var ok: bool = _db.query_with_bindings(
		"INSERT INTO players (username, password_hash, salt, coins, created_at, last_login) VALUES (?, ?, ?, 50, ?, ?)",
		[username, _hash_salted(pw_hash, salt), salt, now, now]
	)

	if ok:
		NetAPI.rpc_id(peer_id, "notify_register", true, "")
	else:
		NetAPI.rpc_id(peer_id, "notify_register", false, "Username already taken.")

# ── Helpers ───────────────────────────────────────────────────────────────────

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
