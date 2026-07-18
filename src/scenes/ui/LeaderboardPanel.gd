extends CanvasLayer

@onready var panel: PanelContainer          = $Panel
@onready var sep: HSeparator                = %Sep0
@onready var rows_container: VBoxContainer  = %RowsContainer
@onready var empty_lbl: Label               = %EmptyLabel

var _expanded := false

func _ready() -> void:
	_set_expanded(false)
	NetAPI.leaderboard_result.connect(_on_leaderboard_result)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _expanded:
		_set_expanded(false)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("leaderboard_toggle"):
		_set_expanded(not _expanded)

func is_expanded() -> bool:
	return _expanded

func set_expanded(expand: bool) -> void:
	_set_expanded(expand)

func _set_expanded(expand: bool) -> void:
	_expanded = expand
	sep.visible = expand
	rows_container.visible = expand
	empty_lbl.visible = false
	if expand:
		NetAPI.rpc_id(1, "c2s_leaderboard_request")

func _on_leaderboard_result(entries: Array) -> void:
	for child in rows_container.get_children():
		child.queue_free()
	if not _expanded:
		return
	if entries.is_empty():
		empty_lbl.visible = true
		return
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 12)
		row.text = "%d. %s — %d" % [i + 1, entry.username, entry.coins]
		if entry.username == GameManager.current_player_name:
			row.modulate = Color(1.0, 0.85, 0.3)
		rows_container.add_child(row)
