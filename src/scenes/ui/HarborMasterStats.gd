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
	NetAPI.rpc_id(1, "c2s_harbor_stats")

func _show_stats(stats: Dictionary) -> void:
	_stats = stats
	var career: Dictionary = stats.get("career", {})
	%General.text = "Time played: %s   •   Login days: %d   •   Longest streak: %d\nCurrent purse: %d gold   •   Highest balance: %d gold\nGold earned: %d   •   Gold spent: %d\nShop spend: %d   •   Items bought: %d   •   Skins bought: %d\nChat sent/received: %d / %d   •   Letters sent/received: %d / %d\nUnique players met: %d\nDerbies entered/won: %d / %d   •   Best place: %d   •   Derby fish: %d" % [_duration(int(career.get("time_played_seconds", 0))), int(career.get("login_days", 0)), int(career.get("longest_login_streak", 0)), int(stats.get("coins", 0)), int(career.get("highest_balance", 0)), int(career.get("total_gold_earned", 0)), int(career.get("total_gold_spent", 0)), int(career.get("shop_spent", 0)), int(career.get("items_bought", 0)), int(career.get("skins_purchased", 0)), int(career.get("chat_messages", 0)), int(career.get("chat_messages_received", 0)), int(career.get("letters_sent", 0)), int(career.get("letters_received", 0)), int(career.get("unique_players_encountered", 0)), int(career.get("derbies_entered", 0)), int(career.get("derbies_won", 0)), int(career.get("best_derby_place", 0)), int(career.get("derby_fish_caught", 0))]
	%Gambling.text = "Hands played: %d   •   Won/lost: %d / %d   •   Win rate: %.1f%%\nTotal wagered: %d   •   Casino profit/loss: %d / %d gold\nBlackjacks: %d   •   Pushes: %d   •   Busts: %d\nDouble downs / wins: %d / %d\nBiggest win/loss: %d / %d gold\nWin streak: %d   •   Loss streak: %d" % [int(career.get("hands_played", 0)), int(career.get("hands_won", 0)), int(career.get("hands_lost", 0)), _win_rate(career), int(career.get("total_wagered", 0)), int(career.get("casino_won", 0)), int(career.get("casino_lost", 0)), int(career.get("blackjacks", 0)), int(career.get("pushes", 0)), int(career.get("busts", 0)), int(career.get("double_downs", 0)), int(career.get("double_downs_won", 0)), int(career.get("biggest_win", 0)), int(career.get("biggest_loss", 0)), int(career.get("longest_win_streak", 0)), int(career.get("longest_loss_streak", 0))]
	%FishingSummary.text = "Fish caught: %d   •   Got away: %d   •   Catch rate: %.1f%%\nPerfect casts: %d   •   Longest streak: %d   •   Fastest catch: %s\nBiggest fish: %.1f in   •   Heaviest junk: %.1f lb\nJunk: %d   •   Treasure: %d   •   Rare: %d   •   Legendary: %d   •   Best catch: %d gold" % [int(career.get("fish_caught", 0)), int(career.get("fish_got_away", 0)), _catch_rate(career), int(career.get("perfect_casts", 0)), int(career.get("longest_fish_streak", 0)), _milliseconds(int(career.get("fastest_catch_ms", 0))), float(career.get("biggest_fish_length", 0)), float(career.get("heaviest_junk", 0)), int(career.get("junk_caught", 0)), int(career.get("treasure_found", 0)), int(career.get("rare_catches", 0)), int(career.get("legendary_catches", 0)), int(career.get("highest_catch_value", 0))]
	%Gear.text = "Gear uses: " + _gear_text(stats.get("gear", []))
	for child in fish_rows.get_children(): child.queue_free()
	var by_id := {}
	for entry: Dictionary in stats.get("fish", []): by_id[str(entry.get("fish_id", ""))] = entry
	for group in [["Fish", func(f: FishData) -> bool: return not f.id.begins_with("junk_") and f.id != "legendary_chest" and f.id != "legendary_key"], ["Junk", func(f: FishData) -> bool: return f.id.begins_with("junk_")], ["Treasure", func(f: FishData) -> bool: return f.id == "legendary_chest" or f.id == "legendary_key"]]:
		var heading := Label.new(); heading.text = str(group[0]); heading.theme_override_font_sizes.font_size = 17; fish_rows.add_child(heading)
		var entries: Array = ItemRegistry.fish.values().filter(group[1])
		entries.sort_custom(func(a: FishData, b: FishData) -> bool: return float(by_id.get(a.id, {}).get("best_measurement" if _sort_by_best else "caught_count", 0)) > float(by_id.get(b.id, {}).get("best_measurement" if _sort_by_best else "caught_count", 0)))
		for fish: FishData in entries:
			if group[1].call(fish): _add_fish_row(fish, by_id.get(fish.id, {}))

func _toggle_sort() -> void:
	_sort_by_best = not _sort_by_best
	%Sort.text = "Sort: Best Size" if _sort_by_best else "Sort: Catch Count"
	if not _stats.is_empty(): _show_stats(_stats)

func _add_fish_row(fish: FishData, stat: Dictionary) -> void:
	var row := HBoxContainer.new(); row.custom_minimum_size.y = 36; row.theme_override_constants.separation = 8
	var icon := TextureRect.new(); icon.custom_minimum_size = ICON_SIZE; icon.texture = _fish_texture(fish); icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; row.add_child(icon)
	var unit := "lb" if fish.id.begins_with("junk_") else "in" if fish.id != "legendary_chest" and fish.id != "legendary_key" else ""
	var best := "   Best: %.1f %s" % [float(stat.get("best_measurement", 0)), unit] if not unit.is_empty() and float(stat.get("best_measurement", 0)) > 0.0 else ""
	var label := Label.new(); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; label.text = "%s   Caught: %d   Got away: %d%s" % [fish.display_name, int(stat.get("caught_count", 0)), int(stat.get("got_away_count", 0)), best]; row.add_child(label)
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
	if event.is_action_pressed("ui_cancel"): _close()

func _close() -> void:
	completed.emit(); queue_free()
