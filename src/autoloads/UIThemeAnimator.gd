extends Node

const ANIMATED_SHEET := preload("res://assets/Complete_UI_Essential_Pack_Free/01_Flat_Theme/Spritesheets/Spritesheet_UI_Flat_Animated.png")
const FRAME_SIZE := Vector2i(32, 32)
const HOVER_ROW := 3
const PRESSED_ROW := 3
const FRAME_COUNT := 4
const FPS := 14.0

var _buttons: Dictionary = {}
var _active_buttons: Array[Button] = []

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_scan_tree(get_tree().root)
	set_process(true)

func _process(delta: float) -> void:
	for button in _active_buttons.duplicate():
		if not is_instance_valid(button) or button.disabled:
			_stop_button(button)
			continue
		var data: Dictionary = _buttons.get(button, {})
		if data.is_empty():
			continue
		data["elapsed"] = float(data.get("elapsed", 0.0)) + delta
		var row := PRESSED_ROW if bool(data.get("pressed", false)) else HOVER_ROW
		var frame := int(float(data["elapsed"]) * FPS) % FRAME_COUNT
		_set_button_frame(data, frame, row)
		_buttons[button] = data

func _scan_tree(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_scan_tree(child)

func _on_node_added(node: Node) -> void:
	var button := node as Button
	if button == null:
		return
	call_deferred("_register_button", button)

func _register_button(button: Button) -> void:
	if not is_instance_valid(button) or _buttons.has(button):
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = ANIMATED_SHEET
	atlas.region = Rect2(Vector2.ZERO, FRAME_SIZE)
	var style := StyleBoxTexture.new()
	style.texture = atlas
	style.texture_margin_left = 8.0
	style.texture_margin_top = 8.0
	style.texture_margin_right = 8.0
	style.texture_margin_bottom = 8.0
	style.content_margin_left = 10.0
	style.content_margin_top = 5.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 5.0
	style.modulate_color = Color(0.7, 0.43, 0.19, 1.0)
	_buttons[button] = {
		"atlas": atlas,
		"style": style,
		"elapsed": 0.0,
		"hovered": false,
		"focused": false,
		"pressed": false,
	}
	button.mouse_entered.connect(_on_button_hovered.bind(button, true))
	button.mouse_exited.connect(_on_button_hovered.bind(button, false))
	button.focus_entered.connect(_on_button_focused.bind(button, true))
	button.focus_exited.connect(_on_button_focused.bind(button, false))
	button.button_down.connect(_on_button_pressed.bind(button, true))
	button.button_up.connect(_on_button_pressed.bind(button, false))
	button.tree_exited.connect(_on_button_exited.bind(button))

func _on_button_hovered(button: Button, hovered: bool) -> void:
	_set_button_active_state(button, "hovered", hovered)

func _on_button_focused(button: Button, focused: bool) -> void:
	_set_button_active_state(button, "focused", focused)

func _on_button_pressed(button: Button, pressed: bool) -> void:
	_set_button_active_state(button, "pressed", pressed)

func _set_button_active_state(button: Button, key: String, value: bool) -> void:
	if not is_instance_valid(button) or not _buttons.has(button):
		return
	var data: Dictionary = _buttons[button]
	data[key] = value
	_buttons[button] = data
	if bool(data.get("hovered", false)) or bool(data.get("focused", false)) or bool(data.get("pressed", false)):
		_start_button(button)
	else:
		_stop_button(button)

func _start_button(button: Button) -> void:
	if button.disabled or not _buttons.has(button):
		return
	var data: Dictionary = _buttons[button]
	var style: StyleBoxTexture = data["style"]
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if not _active_buttons.has(button):
		_active_buttons.append(button)

func _stop_button(button: Button) -> void:
	if _buttons.has(button):
		var data: Dictionary = _buttons[button]
		data["pressed"] = false
		data["elapsed"] = 0.0
		_buttons[button] = data
	if is_instance_valid(button):
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_stylebox_override("hover")
		button.remove_theme_stylebox_override("pressed")
		button.remove_theme_stylebox_override("focus")
	_active_buttons.erase(button)

func _set_button_frame(data: Dictionary, frame: int, row: int) -> void:
	var atlas: AtlasTexture = data["atlas"]
	atlas.region = Rect2(Vector2(frame * FRAME_SIZE.x, row * FRAME_SIZE.y), FRAME_SIZE)

func _on_button_exited(button: Button) -> void:
	_active_buttons.erase(button)
	_buttons.erase(button)
