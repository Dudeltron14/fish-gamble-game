extends CanvasLayer

@onready var panel: PanelContainer          = $Panel
@onready var sep: HSeparator                = %Sep0
@onready var rows_container: VBoxContainer  = %RowsContainer
@onready var empty_lbl: Label               = %EmptyLabel
@onready var title: Label                   = %Title

var _expanded := false
var _metrics := ["coins", "fish", "casino"]
var _metric_index := 0
var _page := 0

const PAGE_SIZE := 8

func _ready() -> void:
	_set_expanded(true)
	NetAPI.leaderboard_result.connect(_on_leaderboard_result)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("leaderboard_toggle"):
		_set_expanded(not _expanded)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_K and not event.echo:
		_metric_index = (_metric_index + 1) % _metrics.size()
		_page = 0
		if _expanded: _request()
		get_viewport().set_input_as_handled()

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
		_request()
	call_deferred("_resize_panel")

func _resize_panel() -> void:
	panel.offset_bottom = panel.offset_top + panel.get_combined_minimum_size().y

func _request() -> void:
	NetAPI.rpc_id(1, "c2s_leaderboard_request", _metrics[_metric_index], _page)

func _on_leaderboard_result(data: Dictionary) -> void:
	if str(data.get("metric", "coins")) != _metrics[_metric_index] or int(data.get("page", 0)) != _page:
		return
	for child in rows_container.get_children():
		child.queue_free()
	if not _expanded:
		return
	var entries: Array = data.get("entries", [])
	var metric_name: String = str({"coins": "COINS", "fish": "FISH CAUGHT", "casino": "CASINO PROFIT"}.get(_metrics[_metric_index], "COINS"))
	title.text = "LEADERBOARD — %s  [K]" % metric_name
	if entries.is_empty():
		empty_lbl.text = "No players listed.  Press K to cycle type."
		empty_lbl.visible = true
		return
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 12)
		row.text = "%d. %s — %d" % [_page * PAGE_SIZE + i + 1, entry.username, int(entry.score)]
		if entry.username == GameManager.current_player_name:
			row.modulate = Color(1.0, 0.85, 0.3)
		rows_container.add_child(row)
	var total := int(data.get("total", entries.size()))
	if total > PAGE_SIZE:
		var pages := HBoxContainer.new()
		var previous := Button.new()
		previous.text = "<"
		previous.disabled = _page == 0
		previous.pressed.connect(func(): _page -= 1; _request())
		pages.add_child(previous)
		var page_label := Label.new()
		page_label.text = "  %d / %d  " % [_page + 1, ceili(float(total) / PAGE_SIZE)]
		pages.add_child(page_label)
		var next := Button.new()
		next.text = ">"
		next.disabled = (_page + 1) * PAGE_SIZE >= total
		next.pressed.connect(func(): _page += 1; _request())
		pages.add_child(next)
		rows_container.add_child(pages)
	call_deferred("_resize_panel")
