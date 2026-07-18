extends CanvasLayer

var _zoom_value: Label
var _ui_scale_value: Label

func _ready() -> void:
	add_to_group("settings_panel")
	layer = 50
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event): if event is InputEventMouseButton and event.pressed: queue_free())
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	box.add_child(HSeparator.new())
	_add_slider(box, "Music", 0.0, 100.0, 1.0, ClientSettings.music_volume, ClientSettings.set_music_volume)
	_add_slider(box, "SFX", 0.0, 100.0, 1.0, ClientSettings.sfx_volume, ClientSettings.set_sfx_volume)
	_zoom_value = _add_slider(box, "View Zoom", 0.25, 1.0, 0.0625, ClientSettings.get_view_zoom_scale(), ClientSettings.set_camera_zoom)
	_ui_scale_value = _add_slider(box, "UI Scale", 0.5, 1.0, 0.05, ClientSettings.ui_scale, ClientSettings.set_ui_scale)
	_refresh_values()
	var world := get_tree().get_first_node_in_group("world")
	if world:
		var disconnect := Button.new()
		disconnect.text = "Disconnect"
		disconnect.pressed.connect(func(): world.disconnect_to_login())
		box.add_child(disconnect)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(queue_free)
	box.add_child(close)
	ClientSettings.register_ui_scale_target(panel, Vector2(0.5, 0.5))

func _add_slider(parent: VBoxContainer, text: String, min_value: float, max_value: float, step: float, value: float, callback: Callable) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(78, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_slider_value_changed.bind(callback))
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(42, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	parent.add_child(row)
	return value_label

func _on_slider_value_changed(value: float, callback: Callable) -> void:
	callback.call(value)
	_refresh_values()

func _refresh_values() -> void:
	if _zoom_value:
		_zoom_value.text = "%d%%" % int(round(ClientSettings.get_view_zoom_scale() * 100.0))
	if _ui_scale_value:
		_ui_scale_value.text = "%d%%" % int(round(ClientSettings.ui_scale * 100.0))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()
