extends CanvasLayer

signal completed

const FISH_SHEET := preload("res://assets/free fish/free fish.png")
const FISH_FRAME_SIZE := Vector2i(16, 16)
const FISH_SHEET_COLUMNS := 3
const ICON_SIZE := Vector2(32, 32)

@onready var fish_rows: VBoxContainer = %FishRows
var _stats: Dictionary = {}
var _sort_by_best := false

func _ready() -> void:
	ClientSettings.register_ui_scale_target($Center/Panel, Vector2(0.5, 0.5))
	NetAPI.harbor_stats_loaded.connect(_show_stats)
	%Close.pressed.connect(_close)
	%Sort.pressed.connect(_toggle_sort)
	%View.pressed.connect(_request_stats)
	%PlayerName.text_submitted.connect(func(_text): _request_stats())
	_request_stats()

func present_with_harbor_master() -> void:
	$Dim.hide()

func _request_stats() -> void:
	NetAPI.rpc_id(1, "c2s_harbor_stats", %PlayerName.text)

func _show_stats(stats: Dictionary) -> void:
	_stats = stats
	%ViewedPlayer.text = "%s’s Brindle Hall of Fame" % str(stats.get("username", GameManager.current_player_name))
	var career: Dictionary = stats.get("career", {})
	_set_table(%General, [
		["Time played", _duration(int(career.get("time_played_seconds", 0)))], ["Login days", int(career.get("login_days", 0))], ["Longest streak", int(career.get("longest_login_streak", 0))],
		["Current purse", "%d gold" % int(stats.get("coins", 0))], ["Highest balance", "%d gold" % int(career.get("highest_balance", 0))], ["Gold earned", int(career.get("total_gold_earned", 0))],
		["Gold spent", int(career.get("total_gold_spent", 0))], ["Shop spend", int(career.get("shop_spent", 0))], ["Items bought", int(career.get("items_bought", 0))],
		["Skins bought", int(career.get("skins_purchased", 0))], ["Chat sent / received", "%d / %d" % [int(career.get("chat_messages", 0)), int(career.get("chat_messages_received", 0))]], ["Letters sent / received", "%d / %d" % [int(career.get("letters_sent", 0)), int(career.get("letters_received", 0))]],
		["Players met", int(career.get("unique_players_encountered", 0))], ["Derbies entered / won", "%d / %d" % [int(career.get("derbies_entered", 0)), int(career.get("derbies_won", 0))]], ["Best derby place", int(career.get("best_derby_place", 0))],
		["Derby fish caught", int(career.get("derby_fish_caught", 0))],
	])
	_set_table(%Gambling, [
		["Hands played", int(career.get("hands_played", 0))], ["Hands won", int(career.get("hands_won", 0))], ["Hands lost", int(career.get("hands_lost", 0))],
		["Win rate", "%.1f%%" % _win_rate(career)], ["Total wagered", int(career.get("total_wagered", 0))], ["Coins won", int(career.get("casino_won", 0))],
		["Coins lost", int(career.get("casino_lost", 0))], ["Blackjacks", int(career.get("blackjacks", 0))], ["Pushes", int(career.get("pushes", 0))],
		["Busts", int(career.get("busts", 0))], ["Double downs / wins", "%d / %d" % [int(career.get("double_downs", 0)), int(career.get("double_downs_won", 0))]], ["Biggest win", "%d gold" % int(career.get("biggest_win", 0))],
		["Biggest loss", "%d gold" % int(career.get("biggest_loss", 0))], ["Win streak", int(career.get("longest_win_streak", 0))], ["Loss streak", int(career.get("longest_loss_streak", 0))],
	])
	_set_table(%FishingSummary, [
		["Fish caught", int(career.get("fish_caught", 0))], ["Got away", int(career.get("fish_got_away", 0))], ["Catch rate", "%.1f%%" % _catch_rate(career)],
		["Perfect casts", int(career.get("perfect_casts", 0))], ["Longest streak", int(career.get("longest_fish_streak", 0))], ["Fastest catch", _milliseconds(int(career.get("fastest_catch_ms", 0)))],
		["Biggest fish", "%.1f in" % float(career.get("biggest_fish_length", 0))], ["Heaviest junk", "%.1f lb" % float(career.get("heaviest_junk", 0))], ["Junk", int(career.get("junk_caught", 0))],
		["Treasure", int(career.get("treasure_found", 0))], ["Rare catches", int(career.get("rare_catches", 0))], ["Legendary catches", int(career.get("legendary_catches", 0))],
		["Best catch", "%d gold" % int(career.get("highest_catch_value", 0))],
	])
	%Gear.text = "Gear uses: " + _gear_text(stats.get("gear", []))
	var history_cells: Array = []
	for entry: Dictionary in stats.get("history", []):
		var fish := ItemRegistry.get_item(str(entry.get("fish_id", ""))) as FishData
		var unit := str(entry.get("measurement_unit", ""))
		history_cells.append([fish.display_name if fish else str(entry.get("fish_id", "Unknown")), "%.1f %s" % [float(entry.get("measurement", 0)), unit] if not unit.is_empty() else "—", "+%d gold" % int(entry.get("earned", 0))])
	_set_table(%History, history_cells)
	for child in fish_rows.get_children(): child.queue_free()
	var by_id := {}
	for entry: Dictionary in stats.get("fish", []): by_id[str(entry.get("fish_id", ""))] = entry
	for group in [["Fish", func(f: FishData) -> bool: return not f.id.begins_with("junk_") and f.id != "legendary_chest" and f.id != "legendary_key"], ["Junk", func(f: FishData) -> bool: return f.id.begins_with("junk_")], ["Treasure", func(f: FishData) -> bool: return f.id == "legendary_chest" or f.id == "legendary_key"]]:
		var heading := Label.new(); heading.text = str(group[0]); heading.add_theme_font_size_override("font_size", 17); fish_rows.add_child(heading)
		var entries: Array = ItemRegistry.fish.values().filter(group[1])
		entries.sort_custom(func(a: FishData, b: FishData) -> bool: return float(by_id.get(a.id, {}).get("best_measurement" if _sort_by_best else "caught_count", 0)) > float(by_id.get(b.id, {}).get("best_measurement" if _sort_by_best else "caught_count", 0)))
		for fish: FishData in entries:
			if group[1].call(fish): _add_fish_row(fish, by_id.get(fish.id, {}))

func _toggle_sort() -> void:
	_sort_by_best = not _sort_by_best
	%Sort.text = "Sort: Best Size" if _sort_by_best else "Sort: Catch Count"
	if not _stats.is_empty(): _show_stats(_stats)

func _set_table(table: GridContainer, cells: Array) -> void:
	for child in table.get_children():
		child.queue_free()
	for cell: Array in cells:
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "%s\n%s" % [str(cell[0]), str(cell[1])]
		table.add_child(label)
	while table.get_child_count() % 3 != 0:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		table.add_child(spacer)

func _add_fish_row(fish: FishData, stat: Dictionary) -> void:
	var row := GridContainer.new(); row.columns = 3; row.custom_minimum_size.y = 36; row.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.theme_override_constants.h_separation = 12
	var identity := HBoxContainer.new(); identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon := TextureRect.new(); icon.custom_minimum_size = ICON_SIZE; icon.texture = _fish_texture(fish); icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; identity.add_child(icon)
	var name_label := Label.new(); name_label.text = fish.display_name; name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; identity.add_child(name_label)
	row.add_child(identity)
	var unit := "lb" if fish.id.begins_with("junk_") else "in" if fish.id != "legendary_chest" and fish.id != "legendary_key" else ""
	var catches := Label.new(); catches.size_flags_horizontal = Control.SIZE_EXPAND_FILL; catches.text = "Caught: %d\nGot away: %d" % [int(stat.get("caught_count", 0)), int(stat.get("got_away_count", 0))]; row.add_child(catches)
	var best := Label.new(); best.size_flags_horizontal = Control.SIZE_EXPAND_FILL; best.text = "Best: %.1f %s" % [float(stat.get("best_measurement", 0)), unit] if not unit.is_empty() and float(stat.get("best_measurement", 0)) > 0.0 else "Best: —"; row.add_child(best)
	fish_rows.add_child(row)

func _fish_texture(fish: FishData) -> Texture2D:
	if fish.icon: return fish.icon
	if fish.sprite_frame < 0: return null
	var atlas := AtlasTexture.new(); var column := fish.sprite_frame % FISH_SHEET_COLUMNS; var row := fish.sprite_frame / FISH_SHEET_COLUMNS
	atlas.atlas = FISH_SHEET; atlas.region = Rect2(column * FISH_FRAME_SIZE.x, row * FISH_FRAME_SIZE.y, FISH_FRAME_SIZE.x, FISH_FRAME_SIZE.y)
	return atlas

func _win_rate(career: Dictionary) -> float:
	var resolved := int(career.get("hands_won", 0)) + int(career.get("hands_lost", 0))
	return 100.0 * float(career.get("hands_won", 0)) / resolved if resolved > 0 else 0.0

func _catch_rate(career: Dictionary) -> float:
	var casts := int(career.get("lines_cast", 0))
	return 100.0 * float(career.get("fish_caught", 0)) / casts if casts > 0 else 0.0

func _gear_text(gear: Array) -> String:
	if gear.is_empty(): return "No bait or hook uses yet."
	var parts: Array[String] = []
	for entry: Dictionary in gear:
		var item := ItemRegistry.get_item(str(entry.get("item_id", "")))
		parts.append("%s × %d" % [item.display_name if item else str(entry.get("item_id", "Unknown")), int(entry.get("uses", 0))])
	return ", ".join(parts)

func _duration(seconds: int) -> String:
	return "%dh %02dm" % [seconds / 3600, (seconds / 60) % 60]

func _milliseconds(milliseconds: int) -> String:
	return "—" if milliseconds <= 0 else "%.1fs" % (milliseconds / 1000.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	completed.emit(); queue_free()
