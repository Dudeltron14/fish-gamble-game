extends CanvasLayer

signal completed

@onready var rows: VBoxContainer = %Rows

func _ready() -> void:
	ClientSettings.register_ui_scale_target($Center/Panel, Vector2(0.5, 0.5))
	NetAPI.daily_quests_loaded.connect(_show_ledger)
	NetAPI.daily_quest_result.connect(_show_result)
	%Close.pressed.connect(_close)
	_refresh()

func _refresh() -> void:
	NetAPI.rpc_id(1, "c2s_daily_quests")

func _show_ledger(ledger: Dictionary) -> void:
	%Info.text = "%d free rerolls left today. More rerolls cost %d gold.  Purse: %d gold" % [int(ledger.get("free_rerolls_left", 0)), int(ledger.get("reroll_cost", 25)), int(ledger.get("coins", 0))]
	for child in rows.get_children(): child.queue_free()
	for quest: Dictionary in ledger.get("quests", []):
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := Label.new(); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var done := int(quest.get("progress", 0)) >= int(quest.get("target", 1))
		label.text = "[%s] %s  %d/%d  •  %d gold" % [str(quest.get("difficulty", "Easy")), _description(quest), int(quest.get("progress", 0)), int(quest.get("target", 0)), int(quest.get("reward", 0))]
		row.add_child(label)
		var reroll := Button.new(); reroll.text = "Reroll"; reroll.pressed.connect(func(): NetAPI.rpc_id(1, "c2s_daily_quest_reroll", int(quest.slot))); row.add_child(reroll)
		var claim := Button.new(); claim.text = "Claim"; claim.disabled = not done or int(quest.get("claimed", 0)) != 0; claim.pressed.connect(func(): NetAPI.rpc_id(1, "c2s_daily_quest_claim", int(quest.slot))); row.add_child(claim)
		rows.add_child(row)

func _description(quest: Dictionary) -> String:
	match str(quest.get("kind", "")):
		"catch_fish":
			var fish := ItemRegistry.get_item(str(quest.get("fish_id", ""))) as FishData
			return "Catch %s" % (fish.display_name if fish else "fish")
		"blackjack_hand": return "Win one blackjack hand for %d gold" % int(quest.get("target", 0))
		_: return "Win %d gold in blackjack" % int(quest.get("target", 0))

func _show_result(ok: bool, reason: String) -> void:
	%Status.text = reason
	%Status.modulate = Color(0.3, 1, 0.4) if ok else Color(1, 0.35, 0.35)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _close()

func _close() -> void:
	completed.emit(); queue_free()
