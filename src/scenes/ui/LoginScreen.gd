extends Control

const DEFAULT_PORT := 7070
const CONNECT_TIMEOUT := 5.0
const AUTH_TIMEOUT := 5.0

enum _Action { NONE, LOGIN, REGISTER }

var _pending := _Action.NONE
var _pending_username := ""
var _pending_hash := ""
var _connect_attempt_id := 0
var _auth_attempt_id := 0

@onready var server_field: LineEdit = %ServerField
@onready var username_field: LineEdit = %UsernameField
@onready var password_field: LineEdit = %PasswordField
@onready var login_btn: Button = %LoginBtn
@onready var register_btn: Button = %RegisterBtn
@onready var host_btn: Button = %HostBtn
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	login_btn.pressed.connect(_on_login_pressed)
	register_btn.pressed.connect(_on_register_pressed)
	host_btn.pressed.connect(_on_host_pressed)
	NetAPI.login_result.connect(_on_login_result)
	NetAPI.register_result.connect(_on_register_result)
	NetworkManager.connected_to_server.connect(_on_network_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)

func _on_host_pressed() -> void:
	var username := username_field.text.strip_edges()
	if username.is_empty():
		username = "Host"
	set_buttons_enabled(false)
	set_status("Starting local server...")

	var err := NetworkManager.start_server(DEFAULT_PORT)
	if err != OK:
		set_status("Could not start server on port %d: %s" % [DEFAULT_PORT, error_string(err)])
		set_buttons_enabled(true)
		return

	GameServer.init_server()
	GameServer.init_host_session(username)
	GameManager.set_player_data(username, 50)
	GameManager.is_hosting = true
	GameManager.go_to_scene("res://src/scenes/world/World.tscn")

func _on_login_pressed() -> void:
	if not _validate():
		return
	_pending = _Action.LOGIN
	_pending_username = username_field.text.strip_edges()
	_pending_hash = _hash_password(password_field.text)
	_maybe_connect()

func _on_register_pressed() -> void:
	if not _validate():
		return
	_pending = _Action.REGISTER
	_pending_username = username_field.text.strip_edges()
	_pending_hash = _hash_password(password_field.text)
	_maybe_connect()

func _maybe_connect() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_execute_pending()
		return

	var server_text := server_field.text.strip_edges()
	if server_text.is_empty():
		server_text = "localhost"
	set_buttons_enabled(false)
	_connect_attempt_id += 1
	var attempt_id: int = _connect_attempt_id
	var err := OK
	if server_text.contains("://"):
		set_status("Connecting to %s..." % server_text)
		err = NetworkManager.connect_to_url(server_text)
	else:
		var parts := server_text.split(":")
		var host := parts[0] if parts.size() > 0 else "localhost"
		var port := int(parts[1]) if parts.size() > 1 else DEFAULT_PORT
		set_status("Connecting to %s:%d..." % [host, port])
		err = NetworkManager.connect_to_server(host, port)

	if err != OK:
		set_status("Connection error: " + error_string(err))
		set_buttons_enabled(true)
		_pending = _Action.NONE
	else:
		_check_connect_timeout(attempt_id)

func _execute_pending() -> void:
	_connect_attempt_id += 1
	_auth_attempt_id += 1
	var auth_attempt_id := _auth_attempt_id
	match _pending:
		_Action.LOGIN:
			set_status("Logging in...")
			NetAPI.rpc_id(1, "request_login", _pending_username, _pending_hash)
		_Action.REGISTER:
			set_status("Registering...")
			NetAPI.rpc_id(1, "request_register", _pending_username, _pending_hash)
	_check_auth_timeout(auth_attempt_id)
	_pending = _Action.NONE

func _on_network_connected() -> void:
	_execute_pending()

func _on_login_result(ok: bool, reason: String, coins: int) -> void:
	_auth_attempt_id += 1
	if ok:
		GameManager.set_player_data(_pending_username, coins)
		GameManager.go_to_scene("res://src/scenes/world/World.tscn")
	else:
		set_status(reason)
		set_buttons_enabled(true)

func _on_register_result(ok: bool, reason: String) -> void:
	_auth_attempt_id += 1
	set_status("Registered! Log in now." if ok else reason)
	set_buttons_enabled(true)

func _on_connection_failed() -> void:
	set_status("Connection failed.")
	set_buttons_enabled(true)
	_pending = _Action.NONE

func _on_server_disconnected() -> void:
	set_status("Disconnected.")
	set_buttons_enabled(true)
	_pending = _Action.NONE

func _check_connect_timeout(attempt_id: int) -> void:
	await get_tree().create_timer(CONNECT_TIMEOUT).timeout
	if attempt_id != _connect_attempt_id:
		return
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		return
	NetworkManager.disconnect_from_server()
	set_status("Connection timed out. Check the server address and port.")
	set_buttons_enabled(true)
	_pending = _Action.NONE

func _check_auth_timeout(attempt_id: int) -> void:
	await get_tree().create_timer(AUTH_TIMEOUT).timeout
	if attempt_id != _auth_attempt_id:
		return
	set_status("Login timed out. The server did not answer.")
	set_buttons_enabled(true)
	_pending = _Action.NONE

func _validate() -> bool:
	var u := username_field.text.strip_edges()
	var p := password_field.text
	if u.is_empty() or p.is_empty():
		set_status("Username and password required.")
		return false
	return true

func _hash_password(password: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(password.to_utf8_buffer())
	return ctx.finish().hex_encode()

func set_status(msg: String) -> void:
	status_label.text = msg

func set_buttons_enabled(enabled: bool) -> void:
	login_btn.disabled = not enabled
	register_btn.disabled = not enabled
	host_btn.disabled = not enabled
