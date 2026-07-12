extends Control

const CONNECT_TIMEOUT := 5.0
const AUTH_TIMEOUT := 5.0
const OFFICIAL_SERVER_URL := "wss://fishserver.dudeltron14.win"
const MENU_EFFECT_REFERENCE_SIZE := Vector2(1280.0, 720.0)

enum _Action { NONE, LOGIN, REGISTER }

var _pending := _Action.NONE
var _pending_username := ""
var _pending_hash := ""
var _connect_attempt_id := 0
var _auth_attempt_id := 0
var _menu_effect_bases := {}
var _selected_server_url := OFFICIAL_SERVER_URL

@onready var official_server_btn: Button = %OfficialServerBtn
@onready var other_server_btn: Button = %OtherServerBtn
@onready var server_url_field: LineEdit = %ServerUrlField
@onready var username_field: LineEdit = %UsernameField
@onready var password_field: LineEdit = %PasswordField
@onready var login_btn: Button = %LoginBtn
@onready var register_btn: Button = %RegisterBtn
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	official_server_btn.pressed.connect(_select_official_server)
	other_server_btn.pressed.connect(_toggle_other_server)
	login_btn.pressed.connect(_on_login_pressed)
	register_btn.pressed.connect(_on_register_pressed)
	NetAPI.login_result.connect(_on_login_result)
	NetAPI.register_result.connect(_on_register_result)
	NetworkManager.connected_to_server.connect(_on_network_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	resized.connect(_layout_menu_effects)
	call_deferred("_capture_menu_effect_bases")

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
	_connect_attempt_id += 1
	var attempt_id: int = _connect_attempt_id
	var server_url := _server_url()
	set_status("Connecting to %s..." % _server_label(server_url))
	var err := NetworkManager.connect_to_url(server_url)

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
	if _server_url().is_empty():
		set_status("Server URL required.")
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
	other_server_btn.disabled = not enabled
	server_url_field.editable = enabled

func _select_official_server() -> void:
	_selected_server_url = OFFICIAL_SERVER_URL
	server_url_field.visible = false
	official_server_btn.text = "Official Server - fishserver.dudeltron14.win"
	other_server_btn.text = "Other Server"
	set_status("")

func _toggle_other_server() -> void:
	var show_field := not server_url_field.visible
	server_url_field.visible = show_field
	if show_field:
		if server_url_field.text.strip_edges().is_empty():
			server_url_field.text = "wss://fishserver-staging.dudeltron14.win"
		_selected_server_url = server_url_field.text.strip_edges()
		official_server_btn.text = "Official Server"
		other_server_btn.text = "Use Other Server"
		server_url_field.grab_focus()
	else:
		_select_official_server()

func _server_url() -> String:
	if server_url_field.visible:
		_selected_server_url = server_url_field.text.strip_edges()
	return _selected_server_url.strip_edges()

func _server_label(server_url: String) -> String:
	if server_url == OFFICIAL_SERVER_URL:
		return "official server"
	return "custom server"

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
