extends CanvasLayer

var _zoom_value: Label
var _ui_scale_value: Label
var _controls_overlay: Control
var _cosmetics_overlay: Control

func _ready() -> void:
	add_to_group("settings_panel")
	NetAPI.cosmetics_equipped.connect(_refresh_cosmetics_selector)
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
	var world := get_tree().get_first_node_in_group("world")
	_add_slider(box, "Music", 0.0, 100.0, 1.0, ClientSettings.music_volume, ClientSettings.set_music_volume)
	_add_slider(box, "SFX", 0.0, 100.0, 1.0, ClientSettings.sfx_volume, ClientSettings.set_sfx_volume)
	if world:
		_add_music_selector(box)
	_zoom_value = _add_slider(box, "View Zoom", 0.5, 2.0, 0.125, ClientSettings.get_view_zoom_scale(), ClientSettings.set_camera_zoom)
	_ui_scale_value = _add_slider(box, "UI Scale", 0.0, 1.5, 0.05, ClientSettings.ui_scale, ClientSettings.set_ui_scale)
	_refresh_values()
	var controls := Button.new()
	controls.text = "Controls"
	controls.pressed.connect(_show_controls)
	box.add_child(controls)
	if world:
		var cosmetics := Button.new()
		cosmetics.text = "Cosmetics"
		cosmetics.pressed.connect(_show_cosmetics)
		box.add_child(cosmetics)
	if world:
		var disconnect := Button.new()
		disconnect.text = "Disconnect"
		disconnect.pressed.connect(func(): world.disconnect_to_login())
		box.add_child(disconnect)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(queue_free)
	box.add_child(close)
	ClientSettings.register_ui_scale_target(panel, Vector2(0.5, 0.5), 0.25)

func _show_controls() -> void:
	if is_instance_valid(_controls_overlay): return
	var overlay := Control.new()
	_controls_overlay = overlay
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.3)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 400)
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
	title.text = "Controls"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	box.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var keys := Label.new()
	keys.text = "WASD / Arrow Keys\nE\nT\nTab\nL\nK\nESC"
	keys.add_theme_font_size_override("font_size", 18)
	keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(keys)
	columns.add_child(VSeparator.new())
	var actions := Label.new()
	actions.text = "Move\nHold to fish / interact\nLocal chat\nGear modifiers\nExpand / collapse leaderboard\nCycle leaderboard metric\nSettings"
	actions.add_theme_font_size_override("font_size", 18)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	columns.add_child(actions)
	box.add_child(columns)
	var note := Label.new()
	note.text = "Typing in chat pauses movement."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(overlay.queue_free)
	box.add_child(close)

func _show_cosmetics() -> void:
	if is_instance_valid(_cosmetics_overlay): return
	var overlay := Control.new()
	_cosmetics_overlay = overlay
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.3)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 420)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Cosmetics"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	box.add_child(HSeparator.new())
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	_add_cosmetic_tab(tabs, "skins", "Player Skins")
	_add_cosmetic_tab(tabs, "bobbers", "Bobbers")
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(overlay.queue_free)
	box.add_child(close)

func _add_cosmetic_tab(tabs: TabContainer, category: String, title: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var found := false
	for item: Dictionary in CosmeticCatalog.get_category(category):
		if not bool(item.get("default", false)) and GameManager.get_owned(str(item.id)) <= 0:
			continue
		found = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var icon := TextureRect.new()
		icon.texture = CosmeticCatalog.icon_for(item)
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var label := Label.new()
		label.text = "%s\n%s" % [str(item.name), str(item.description)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		var equipped: bool = GameManager.equipped_skin_id == item.id if category == "skins" else GameManager.equipped_bobber_id == item.id
		var equip := Button.new()
		equip.text = "Equipped" if equipped else "Equip"
		equip.disabled = equipped
		equip.pressed.connect(func(): NetAPI.rpc_id(1, "c2s_equip_cosmetic", str(item.id)))
		row.add_child(equip)
		list.add_child(row)
		list.add_child(HSeparator.new())
	if not found:
		var empty := Label.new()
		empty.text = "No %s owned yet. Visit the Fish Shop." % category
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty)

func _refresh_cosmetics_selector(_skin_id: String, _bobber_id: String) -> void:
	if not is_instance_valid(_cosmetics_overlay):
		return
	_cosmetics_overlay.queue_free()
	call_deferred("_show_cosmetics")

func _add_music_selector(parent: VBoxContainer) -> void:
	var now_playing := Label.new()
	now_playing.text = "Now playing: %s" % AudioManager.current_track_name()
	now_playing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(now_playing)
	var picker := OptionButton.new()
	picker.add_item("Music: Auto")
	for path: String in AudioManager.selectable_world_track_paths():
		picker.add_item(path.get_file().get_basename())
		picker.set_item_metadata(picker.item_count - 1, path)
		if path == ClientSettings.world_track:
			picker.select(picker.item_count - 1)
	picker.item_selected.connect(func(index):
		ClientSettings.set_world_track(str(picker.get_item_metadata(index)) if index > 0 else "")
		now_playing.text = "Now playing: %s" % AudioManager.current_track_name()
	)
	parent.add_child(picker)

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
		if is_instance_valid(_controls_overlay):
			_controls_overlay.queue_free()
		elif is_instance_valid(_cosmetics_overlay):
			_cosmetics_overlay.queue_free()
		else:
			queue_free()
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()
