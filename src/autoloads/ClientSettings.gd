extends Node

const SETTINGS_FILE := "user://settings.cfg"
const SETTINGS_PANEL := preload("res://src/scenes/ui/SettingsPanel.gd")
const UI_SCALE_BASE := 1.0
const UI_SCALE_VERSION := 3
const VIEW_ZOOM_BASE := 4.0
const VIEW_ZOOM_VERSION := 2

var music_volume := 80.0
var sfx_volume := 80.0
var ui_scale := 1.0

func _ready() -> void:
	_load_global_settings()
	call_deferred("_apply_global_settings")

func open(parent: Node) -> void:
	if is_open():
		return
	parent.add_child(SETTINGS_PANEL.new())

func is_open() -> bool:
	return not get_tree().get_nodes_in_group("settings_panel").is_empty()

func load_player_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_zoom_settings_file()) != OK or cfg.get_value("gameplay", "zoom_version", 1) < VIEW_ZOOM_VERSION:
		GameManager.set_camera_zoom(VIEW_ZOOM_BASE)
		cfg.set_value("gameplay", "camera_zoom", VIEW_ZOOM_BASE)
		cfg.set_value("gameplay", "zoom_version", VIEW_ZOOM_VERSION)
		cfg.save(_zoom_settings_file())
		return
	GameManager.set_camera_zoom(cfg.get_value("gameplay", "camera_zoom", VIEW_ZOOM_BASE))

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 100.0)
	AudioManager.set_music_volume(music_volume / 100.0)
	_save_global_settings()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 100.0)
	AudioManager.set_sfx_volume(sfx_volume / 100.0)
	_save_global_settings()

func set_ui_scale(value: float) -> void:
	ui_scale = clampf(value, 0.75, 1.5)
	_apply_ui_scale()
	_save_global_settings()

func set_camera_zoom(value: float) -> void:
	GameManager.set_camera_zoom(value * VIEW_ZOOM_BASE)
	var cfg := ConfigFile.new()
	cfg.set_value("gameplay", "camera_zoom", GameManager.camera_zoom)
	cfg.set_value("gameplay", "zoom_version", VIEW_ZOOM_VERSION)
	cfg.save(_zoom_settings_file())

func get_view_zoom_scale() -> float:
	return GameManager.camera_zoom / VIEW_ZOOM_BASE

func _load_global_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) != OK:
		return
	music_volume = cfg.get_value("audio", "music_volume", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx_volume", sfx_volume)
	if cfg.get_value("display", "ui_scale_version", 1) < UI_SCALE_VERSION:
		ui_scale = 1.0
		cfg.set_value("display", "ui_scale", ui_scale)
		cfg.set_value("display", "ui_scale_version", UI_SCALE_VERSION)
		cfg.save(SETTINGS_FILE)
	else:
		ui_scale = cfg.get_value("display", "ui_scale", ui_scale)

func _apply_global_settings() -> void:
	AudioManager.set_music_volume(music_volume / 100.0)
	AudioManager.set_sfx_volume(sfx_volume / 100.0)
	_apply_ui_scale()

func _apply_ui_scale() -> void:
	for target in get_tree().get_nodes_in_group("ui_scale_target"):
		_apply_ui_scale_target(target as Control)

func register_ui_scale_target(control: Control, pivot: Vector2) -> void:
	control.add_to_group("ui_scale_target")
	control.set_meta("ui_scale_pivot", pivot)
	control.resized.connect(_apply_ui_scale_target.bind(control))
	_apply_ui_scale_target(control)

func _apply_ui_scale_target(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.pivot_offset = control.size * control.get_meta("ui_scale_pivot", Vector2(0.5, 0.5))
	control.scale = Vector2.ONE * UI_SCALE_BASE * ui_scale

func _save_global_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("display", "ui_scale", ui_scale)
	cfg.set_value("display", "ui_scale_version", UI_SCALE_VERSION)
	cfg.save(SETTINGS_FILE)

func _zoom_settings_file() -> String:
	return "user://zoom_%s.cfg" % GameManager.current_player_name
