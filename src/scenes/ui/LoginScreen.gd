extends Control

const CONNECT_TIMEOUT := 5.0
const AUTH_TIMEOUT := 5.0
const STATUS_CONNECT_TIMEOUT := 12.0
const STATUS_QUERY_RETRY_DELAY := 0.75
const SERVER_URL := "wss://fishserver.dudeltron14.win"
const SERVER_LABEL := "Production Server"
const MENU_EFFECT_REFERENCE_SIZE := Vector2(1280.0, 720.0)

enum _Action { NONE, LOGIN, REGISTER }

var _pending := _Action.NONE
var _pending_username := ""
var _pending_hash := ""
var _connect_attempt_id := 0
var _auth_attempt_id := 0
var _status_attempt_id := 0
var _checking_server_status := false
var _menu_effect_bases := {}

@onready var official_server_btn: Button = %OfficialServerBtn
@onready var server_status_label: Label = %ServerStatusLabel
@onready var username_field: LineEdit = %UsernameField
@onready var password_field: LineEdit = %PasswordField
@onready var login_btn: Button = %LoginBtn
@onready var register_btn: Button = %RegisterBtn
@onready var settings_btn: Button = %SettingsBtn
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	official_server_btn.text = "%s - %s" % [SERVER_LABEL, SERVER_URL.replace("wss://", "")]
	official_server_btn.tooltip_text = "Click to refresh server status. This client is locked to %s." % SERVER_URL
	official_server_btn.pressed.connect(_request_server_status)
	login_btn.pressed.connect(_on_login_pressed)
	register_btn.pressed.connect(_on_register_pressed)
	settings_btn.pressed.connect(func(): ClientSettings.open(self))
	NetAPI.login_result.connect(_on_login_result)
	NetAPI.register_result.connect(_on_register_result)
	NetAPI.server_status.connect(_on_server_status)
	NetworkManager.connected_to_server.connect(_on_network_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	resized.connect(_layout_menu_effects)
	call_deferred("_capture_menu_effect_bases")
	_request_server_status()

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
	set_buttons_enabled(false)
	var connection_status := NetworkManager.get_connection_status()
	if connection_status == MultiplayerPeer.CONNECTION_CONNECTED:
		_execute_pending()
		return
	if connection_status == MultiplayerPeer.CONNECTION_CONNECTING:
		set_status("Connecting to %s..." % SERVER_LABEL.to_lower())
		return
	_connect_attempt_id += 1
	var attempt_id: int = _connect_attempt_id
	set_status("Connecting to %s..." % SERVER_LABEL.to_lower())
	var err := NetworkManager.connect_to_url(SERVER_URL)

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
	if _pending == _Action.NONE:
		if _checking_server_status:
			_send_server_status_query(_status_attempt_id)
	else:
		_execute_pending()

func _on_login_result(ok: bool, reason: String, coins: int) -> void:
	_auth_attempt_id += 1
	if ok:
		GameManager.set_player_data(_pending_username, coins)
		ClientSettings.load_player_settings()
		GameManager.go_to_scene("res://src/scenes/world/World.tscn")
	else:
		set_status(reason)
		set_buttons_enabled(true)

func _on_register_result(ok: bool, reason: String) -> void:
	_auth_attempt_id += 1
	set_status("Registered! Log in now." if ok else reason)
	set_buttons_enabled(true)

func _on_connection_failed() -> void:
	_checking_server_status = false
	_set_server_status("Offline", false)
	set_status("Connection failed.")
	set_buttons_enabled(true)
	_pending = _Action.NONE

func _on_server_disconnected() -> void:
	if _pending == _Action.NONE:
		_checking_server_status = false
		_set_server_status("Offline", false)
		return
	set_status("Disconnected.")
	set_buttons_enabled(true)
	_pending = _Action.NONE

func _check_connect_timeout(attempt_id: int) -> void:
	await get_tree().create_timer(CONNECT_TIMEOUT).timeout
	if attempt_id != _connect_attempt_id:
		return
	if NetworkManager.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
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

func _request_server_status() -> void:
	_checking_server_status = true
	_status_attempt_id += 1
	var attempt_id := _status_attempt_id
	_set_server_status("Checking server…", true)
	var connection_status := NetworkManager.get_connection_status()
	if connection_status == MultiplayerPeer.CONNECTION_CONNECTED:
		_send_server_status_query(attempt_id)
		return
	if connection_status == MultiplayerPeer.CONNECTION_CONNECTING:
		_check_server_status_connection_timeout(attempt_id)
		return
	if NetworkManager.connect_to_url(SERVER_URL) != OK:
		_checking_server_status = false
		_set_server_status("Offline", false)
		return
	_check_server_status_connection_timeout(attempt_id)

func _send_server_status_query(attempt_id: int) -> void:
	NetAPI.rpc_id(1, "c2s_server_status", Time.get_ticks_msec())
	_retry_server_status_query(attempt_id)
	_check_server_status_timeout(attempt_id)

func _retry_server_status_query(attempt_id: int) -> void:
	await get_tree().create_timer(STATUS_QUERY_RETRY_DELAY).timeout
	if attempt_id != _status_attempt_id or not _checking_server_status:
		return
	if NetworkManager.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		NetAPI.rpc_id(1, "c2s_server_status", Time.get_ticks_msec())

func _check_server_status_connection_timeout(attempt_id: int) -> void:
	await get_tree().create_timer(STATUS_CONNECT_TIMEOUT).timeout
	if attempt_id != _status_attempt_id or not _checking_server_status:
		return
	if NetworkManager.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_checking_server_status = false
	NetworkManager.disconnect_from_server()
	_set_server_status("Offline", false)

func _check_server_status_timeout(attempt_id: int) -> void:
	await get_tree().create_timer(CONNECT_TIMEOUT).timeout
	if attempt_id != _status_attempt_id or not _checking_server_status:
		return
	_checking_server_status = false
	NetworkManager.disconnect_from_server()
	_set_server_status("Offline", false)

func _on_server_status(player_count: int, sent_ms: int) -> void:
	_checking_server_status = false
	var ping_ms := maxi(0, Time.get_ticks_msec() - sent_ms)
	_set_server_status("Online • %d %s • %d ms" % [player_count, "player" if player_count == 1 else "players", ping_ms], true)

func _set_server_status(text: String, online: bool) -> void:
	server_status_label.text = text
	server_status_label.modulate = Color(0.35, 1.0, 0.5) if online else Color(1.0, 0.45, 0.45)

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
	official_server_btn.disabled = not enabled

func _capture_menu_effect_bases() -> void:
	_menu_effect_bases.clear()
	for child in get_children():
		var sprite := child as Sprite2D
		if sprite == null or not sprite.name.begins_with("Menu"):
			continue
		_menu_effect_bases[sprite] = {
			"position": sprite.position,
			"scale": sprite.scale,
		}
	_layout_menu_effects()

func _layout_menu_effects() -> void:
	if _menu_effect_bases.is_empty():
		return
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	var cover_scale := maxf(
		viewport_size.x / MENU_EFFECT_REFERENCE_SIZE.x,
		viewport_size.y / MENU_EFFECT_REFERENCE_SIZE.y
	)
	var offset := (viewport_size - MENU_EFFECT_REFERENCE_SIZE * cover_scale) * 0.5
	for sprite: Sprite2D in _menu_effect_bases:
		if not is_instance_valid(sprite):
			continue
		var base: Dictionary = _menu_effect_bases[sprite]
		sprite.position = Vector2(base["position"]) * cover_scale + offset
		sprite.scale = Vector2(base["scale"]) * cover_scale
