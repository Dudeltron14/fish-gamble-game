extends Node

const SETTINGS_FILE := "user://settings.cfg"
const SETTINGS_PANEL := preload("res://src/scenes/ui/SettingsPanel.gd")

var music_volume := 80.0
var sfx_volume := 80.0
var ui_scale := 1.5

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
	if cfg.load(_zoom_settings_file()) == OK:
		GameManager.set_camera_zoom(cfg.get_value("gameplay", "camera_zoom", 2.0))
	else:
		GameManager.set_camera_zoom(2.0)

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 100.0)
	AudioManager.set_music_volume(music_volume / 100.0)
	_save_global_settings()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 100.0)
	AudioManager.set_sfx_volume(sfx_volume / 100.0)
	_save_global_settings()

func set_ui_scale(value: float) -> void:
	ui_scale = clampf(value, 0.75, 2.0)
	get_window().content_scale_factor = ui_scale
	_save_global_settings()

func set_camera_zoom(value: float) -> void:
	GameManager.set_camera_zoom(value)
	var cfg := ConfigFile.new()
	cfg.set_value("gameplay", "camera_zoom", GameManager.camera_zoom)
	cfg.save(_zoom_settings_file())

func _load_global_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) != OK:
		return
	music_volume = cfg.get_value("audio", "music_volume", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx_volume", sfx_volume)
	ui_scale = cfg.get_value("display", "ui_scale", ui_scale)

func _apply_global_settings() -> void:
	AudioManager.set_music_volume(music_volume / 100.0)
	AudioManager.set_sfx_volume(sfx_volume / 100.0)
	get_window().content_scale_factor = ui_scale

func _save_global_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("display", "ui_scale", ui_scale)
	cfg.save(SETTINGS_FILE)

func _zoom_settings_file() -> String:
	return "user://zoom_%s.cfg" % GameManager.current_player_name
