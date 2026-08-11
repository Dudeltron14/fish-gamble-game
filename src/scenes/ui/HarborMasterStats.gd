extends CanvasLayer

signal completed

const FISH_SHEET := preload("res://assets/free fish/free fish.png")
const FISH_FRAME_SIZE := Vector2i(16, 16)
const FISH_SHEET_COLUMNS := 3
const ICON_SIZE := Vector2(32, 32)

@onready var fish_rows: VBoxContainer = %FishRows
@onready var collection_rows: VBoxContainer = %Rows
@onready var player_picker: OptionButton = %PlayerPicker
var _stats: Dictionary = {}
var _sort_by_best := false
var _compare_mode := false
var _viewer_career: Dictionary = {}
var _viewer_coins := 0
var _viewer_fish: Dictionary = {}

func _ready() -> void:
	ClientSettings.register_ui_scale_target($Center/Panel, Vector2(0.5, 0.5))
	var tabs: TabContainer = $Center/Panel/Margin/VBox/Tabs
	tabs.set_tab_title(0, "General Stats")
	tabs.set_tab_title(1, "Fishing Stats")
	tabs.set_tab_title(2, "Gambling Stats")
	tabs.set_tab_title(3, "Collections")
	NetAPI.harbor_stats_loaded.connect(_show_stats)
	%Close.pressed.connect(_close)
	%Sort.pressed.connect(_toggle_sort)
	%Compare.pressed.connect(_toggle_compare)
	player_picker.item_selected.connect(func(index: int): _request_stats(player_picker.get_item_text(index)))
	_request_stats()

func present_with_harbor_master() -> void:
	$Dim.hide()

func _request_stats(username: String = "") -> void:
	NetAPI.rpc_id(1, "c2s_harbor_stats", "" if username == "My Stats" else username)

func _show_stats(stats: Dictionary) -> void:
	_stats = stats
	_viewer_career = stats.get("viewer_career", {})
	_viewer_coins = int(stats.get("viewer_coins", 0))
	_viewer_fish.clear()
	for entry: Dictionary in stats.get("viewer_fish", []):
		_viewer_fish[str(entry.get("fish_id", ""))] = entry
	_populate_picker(stats.get("players", []), str(stats.get("username", "")))
	%Compare.disabled = str(stats.get("username", "")) == GameManager.current_player_name
	if %Compare.disabled:
		_compare_mode = false
	%Compare.text = "Comparing" if _compare_mode else "Compare"
	%ViewedPlayer.text = "%s’s Brindle Hall of Fame" % str(stats.get("username", GameManager.current_player_name))
	var career: Dictionary = stats.get("career", {})
	_set_table(%General, [
		["Time played", _duration(int(career.get("time_played_seconds", 0))), "time_played_seconds"], ["Login days", int(career.get("login_days", 0)), "login_days"], ["Longest streak", int(career.get("longest_login_streak", 0)), "longest_login_streak"],
		["Current purse", "%d gold" % int(stats.get("coins", 0)), "coins", int(stats.get("coins", 0))], ["Highest balance", "%d gold" % int(career.get("highest_balance", 0)), "highest_balance"], ["Gold earned", int(career.get("total_gold_earned", 0)), "total_gold_earned"],
		["Gold spent", int(career.get("total_gold_spent", 0))], ["Shop spend", int(career.get("shop_spent", 0))], ["Items bought", int(career.get("items_bought", 0))],
		["Skins bought", int(career.get("skins_purchased", 0))], ["Chat sent / received", "%d / %d" % [int(career.get("chat_messages", 0)), int(career.get("chat_messages_received", 0))]], ["Letters sent / received", "%d / %d" % [int(career.get("letters_sent", 0)), int(career.get("letters_received", 0))]],
		["Players met", int(career.get("unique_players_encountered", 0))], ["Derbies entered / won", "%d / %d" % [int(career.get("derbies_entered", 0)), int(career.get("derbies_won", 0))]], ["Best derby place", int(career.get("best_derby_place", 0))],
		["Derby fish caught", int(career.get("derby_fish_caught", 0)), "derby_fish_caught"], ["Quest gold earned", int(career.get("quest_gold_earned", 0)), "quest_gold_earned"], ["Quests completed", int(career.get("quests_completed", 0)), "quests_completed"],
		["Free / paid rerolls", "%d / %d" % [int(career.get("free_quest_rerolls", 0)), int(career.get("paid_quest_rerolls", 0))]], ["Legendary quests", int(career.get("legendary_quests_completed", 0))],
	])
	_set_table(%Gambling, [
		["Hands played", int(career.get("hands_played", 0)), "hands_played"], ["Hands won", int(career.get("hands_won", 0)), "hands_won"], ["Hands lost", int(career.get("hands_lost", 0)), "hands_lost"],
		["Win rate", "%.1f%%" % _win_rate(career)], ["Total wagered", int(career.get("total_wagered", 0)), "total_wagered"], ["Coins won", int(career.get("casino_won", 0)), "casino_won"],
		["Coins lost", int(career.get("casino_lost", 0)), "casino_lost"], ["Blackjacks", int(career.get("blackjacks", 0)), "blackjacks"], ["Pushes", int(career.get("pushes", 0)), "pushes"],
		["Busts", int(career.get("busts", 0)), "busts"], ["Double downs / wins", "%d / %d" % [int(career.get("double_downs", 0)), int(career.get("double_downs_won", 0))]], ["Biggest win", "%d gold" % int(career.get("biggest_win", 0)), "biggest_win"],
		["Biggest loss", "%d gold" % int(career.get("biggest_loss", 0)), "biggest_loss"], ["Biggest win streak", int(career.get("longest_win_streak", 0)), "longest_win_streak"], ["Biggest loss streak", int(career.get("longest_loss_streak", 0)), "longest_loss_streak"],
	])
	_set_table(%FishingSummary, [
		["Fish caught", int(career.get("fish_caught", 0)), "fish_caught"], ["Got away", int(career.get("fish_got_away", 0)), "fish_got_away"], ["Catch rate", "%.1f%%" % _catch_rate(career)],
		["Perfect casts", int(career.get("perfect_casts", 0)), "perfect_casts"], ["Longest streak", int(career.get("longest_fish_streak", 0)), "longest_fish_streak"], ["Fastest catch", _milliseconds(int(career.get("fastest_catch_ms", 0)))],
		["Biggest fish", "%.1f in" % float(career.get("biggest_fish_length", 0)), "biggest_fish_length"], ["Heaviest junk", "%.1f lb" % float(career.get("heaviest_junk", 0)), "heaviest_junk"], ["Junk", int(career.get("junk_caught", 0)), "junk_caught"],
		["Treasure", int(career.get("treasure_found", 0)), "treasure_found"], ["Rare catches", int(career.get("rare_catches", 0)), "rare_catches"], ["Legendary catches", int(career.get("legendary_catches", 0)), "legendary_catches"],
		["Best catch", "%d gold" % int(career.get("highest_catch_value", 0)), "highest_catch_value"],
	])
	%Gear.text = "Gear uses: " + _gear_text(stats.get("gear", []))
	for child in fish_rows.get_children(): child.queue_free()
	var by_id := {}
	for entry: Dictionary in stats.get("fish", []): by_id[str(entry.get("fish_id", ""))] = entry
	for category in ["Fish", "Junk", "Treasure"]:
		var entries: Array[FishData] = []
		for fish: FishData in ItemRegistry.fish.values():
			var stat: Dictionary = by_id.get(fish.id, {})
			if _catch_category(fish) == category and (int(stat.get("caught_count", 0)) > 0 or int(stat.get("got_away_count", 0)) > 0):
				entries.append(fish)
		if entries.is_empty():
			continue
		var heading := Label.new(); heading.text = category; heading.add_theme_font_size_override("font_size", 23); fish_rows.add_child(heading)
		entries.sort_custom(func(a: FishData, b: FishData) -> bool: return float(by_id.get(a.id, {}).get("best_measurement" if _sort_by_best else "caught_count", 0)) > float(by_id.get(b.id, {}).get("best_measurement" if _sort_by_best else "caught_count", 0)))
		for fish: FishData in entries:
			_add_fish_row(fish, by_id.get(fish.id, {}))
	_populate_collection(by_id)

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
		var key := str(cell[2]) if cell.size() > 2 else ""
		var target := float(cell[3]) if cell.size() > 3 else float(_stats.get("coins", 0)) if key == "coins" else float(_stats.get("career", {}).get(key, 0))
		var comparison := _comparison(key, target)
		label.text = "%s\n%s%s" % [str(cell[0]), str(cell[1]), str(comparison.get("arrow", ""))]
		label.modulate = comparison.get("color", Color.WHITE)
		table.add_child(label)
	while table.get_child_count() % 3 != 0:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		table.add_child(spacer)

func _add_fish_row(fish: FishData, stat: Dictionary) -> void:
	var row := HBoxContainer.new(); row.custom_minimum_size = Vector2(0, 36); row.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_theme_constant_override("separation", 12)
	var identity := HBoxContainer.new(); identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon := TextureRect.new(); icon.custom_minimum_size = ICON_SIZE; icon.texture = _fish_texture(fish); icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; identity.add_child(icon)
	var name_label := Label.new(); name_label.text = fish.display_name; name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; identity.add_child(name_label)
	row.add_child(identity)
	var unit := "lb" if fish.id.begins_with("junk_") else "in" if fish.id != "legendary_chest" and fish.id != "legendary_key" else ""
	var mine: Dictionary = _viewer_fish.get(fish.id, {})
	var tracks_escapes := _catch_category(fish) == "Fish"
	var escaped_only := tracks_escapes and int(stat.get("caught_count", 0)) == 0 and int(stat.get("got_away_count", 0)) > 0
	var catches_compare := {} if escaped_only else _comparison_values(float(mine.get("caught_count", 0)), float(stat.get("caught_count", 0)))
	var catches := Label.new(); catches.custom_minimum_size.x = 150; catches.text = "Caught: 0\nGot away: %d" % int(stat.get("got_away_count", 0)) if escaped_only else "Caught: %d%s\nGot away: %d" % [int(stat.get("caught_count", 0)), str(catches_compare.get("arrow", "")), int(stat.get("got_away_count", 0))] if tracks_escapes else "Caught: %d%s" % [int(stat.get("caught_count", 0)), str(catches_compare.get("arrow", ""))]; catches.modulate = catches_compare.get("color", Color.WHITE); row.add_child(catches)
	var best_compare := {} if escaped_only else _comparison_values(float(mine.get("best_measurement", 0)), float(stat.get("best_measurement", 0)))
	var best := Label.new(); best.custom_minimum_size.x = 150; best.text = "Best: ????" if escaped_only else "Best: %.1f %s%s" % [float(stat.get("best_measurement", 0)), unit, str(best_compare.get("arrow", ""))] if not unit.is_empty() and float(stat.get("best_measurement", 0)) > 0.0 else "Best: —"; best.modulate = best_compare.get("color", Color.WHITE); row.add_child(best)
	fish_rows.add_child(row)

func _populate_collection(by_id: Dictionary) -> void:
	for child in collection_rows.get_children(): child.queue_free()
	for category in ["Fish", "Junk", "Treasure"]:
		var heading := Label.new()
		heading.text = category
		heading.add_theme_font_size_override("font_size", 20)
		collection_rows.add_child(heading)
		for fish: FishData in ItemRegistry.fish.values():
			if _catch_category(fish) != category: continue
			var stat: Dictionary = by_id.get(fish.id, {})
			_add_collection_row(fish, stat)

func _add_collection_row(fish: FishData, stat: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 36)
	row.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.texture = _fish_texture(fish)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var label := Label.new()
	var caught := int(stat.get("caught_count", 0))
	var away := int(stat.get("got_away_count", 0))
	var unit := "lb" if fish.id.begins_with("junk_") else "in" if _catch_category(fish) == "Fish" else ""
	var best := float(stat.get("best_measurement", 0.0))
	var size_text := ""
	if not unit.is_empty() and caught > 0: size_text = " · Best %.1f %s" % [best, unit]
	label.text = "%s  ·  Caught %d%s%s" % [fish.display_name, caught, " · Away %d" % away if _catch_category(fish) == "Fish" else "", size_text]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	collection_rows.add_child(row)

func _catch_category(fish: FishData) -> String:
	if fish.id.begins_with("junk_"):
		return "Junk"
	if fish.id == "legendary_chest" or fish.id == "legendary_key":
		return "Treasure"
	return "Fish"

func _populate_picker(players: Array, viewed_username: String) -> void:
	player_picker.clear()
	player_picker.add_item("My Stats")
	for entry: Dictionary in players:
		var username := str(entry.get("username", ""))
		if not username.is_empty() and username != GameManager.current_player_name:
			player_picker.add_item(username)
	for index in player_picker.item_count:
		if player_picker.get_item_text(index) == viewed_username or (viewed_username == GameManager.current_player_name and index == 0):
			player_picker.select(index)
			return

func _toggle_compare() -> void:
	_compare_mode = not _compare_mode
	_show_stats(_stats)

func _comparison(key: String, target: float) -> Dictionary:
	if not _compare_mode or key.is_empty():
		return {}
	var mine := float(_viewer_coins) if key == "coins" else float(_viewer_career.get(key, 0))
	return _comparison_values(mine, target, key in ["fish_got_away", "casino_lost", "biggest_loss", "total_gold_spent"])

func _comparison_values(mine: float, target: float, lower_is_better: bool = false) -> Dictionary:
	if not _compare_mode or is_equal_approx(mine, target):
		return {}
	var mine_is_better := mine < target if lower_is_better else mine > target
	return {"arrow": "  +" if mine_is_better else "  -", "color": Color(0.35, 1.0, 0.45) if mine_is_better else Color(1.0, 0.42, 0.38)}

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
