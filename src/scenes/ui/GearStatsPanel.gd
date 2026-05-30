extends CanvasLayer

@onready var panel: PanelContainer   = $Panel
@onready var rod_lbl: Label          = %RodSection
@onready var bait_lbl: Label         = %BaitSection
@onready var hook_lbl: Label         = %HookSection
@onready var cast_lbl: Label         = %CastSection

var _visible_state := true

func _ready() -> void:
	GameManager.equipped_changed.connect(_refresh)
	GameManager.hook_durability_changed.connect(func(_c, _m): _refresh())
	GameManager.owned_changed.connect(_refresh)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("stats_toggle"):
		_visible_state = not _visible_state
		panel.visible = _visible_state

func _refresh() -> void:
	var rod    := ItemRegistry.get_item(GameManager.equipped_rod_id)    as RodData
	var bait   := ItemRegistry.get_item(GameManager.equipped_bait_id)   as BaitData
	var tackle := ItemRegistry.get_item(GameManager.equipped_tackle_id) as TackleData

	# ── Rod ──────────────────────────────────────────────────────────────────
	if rod:
		var cast_t := 100.0 / (60.0 * rod.cast_speed)
		var catch_t := 1.0 / (0.35 * rod.line_strength)
		rod_lbl.text = (
			"ROD: %s\n" % rod.display_name +
			"  Cast speed:   x%.1f  (fills in %.1fs)\n" % [rod.cast_speed, cast_t] +
			"  Reel speed:   x%.1f  (%.1fs to catch)\n" % [rod.line_strength, catch_t] +
			"  Rarity bonus: +%d%%" % int(rod.rarity_bonus * 100)
		)
	else:
		rod_lbl.text = "ROD: None"

	# ── Bait ─────────────────────────────────────────────────────────────────
	if bait:
		var owned := GameManager.get_owned(bait.id)
		var wait_pct := int((1.0 - bait.wait_modifier) * 100.0)
		var tier := _bait_tier_label(bait)
		bait_lbl.text = (
			"BAIT: %s (x%d)\n" % [bait.display_name, owned] +
			"  Bite speed:   -%d%% wait\n" % wait_pct +
			"  Fish pool:    %s" % tier
		)
	else:
		bait_lbl.text = "BAIT: None\n  Fish pool:    Common only"

	# ── Hook ─────────────────────────────────────────────────────────────────
	if tackle:
		var dur_cur := GameManager.hook_durability
		var dur_max := GameManager.hook_max_durability
		hook_lbl.text = (
			"HOOK: %s  %d/%d\n" % [tackle.display_name, dur_cur, dur_max] +
			"  Coin bonus:   x%.1f\n" % tackle.coin_multiplier +
			"  React window: +%d%%" % int(tackle.escape_reduction * 100)
		)
	else:
		hook_lbl.text = "HOOK: None"

	# ── Cast quality note ────────────────────────────────────────────────────
	cast_lbl.text = "Cast quality affects rarity + bite wait.\nPerfect cast: +10% rare/legendary."

func _bait_tier_label(bait: BaitData) -> String:
	var w := bait.rarity_weights
	var parts := []
	if w.get("common", 0.0) > 0.0:
		parts.append("Common %.0f%%" % (w["common"] * 100))
	if w.get("uncommon", 0.0) > 0.0:
		parts.append("Uncommon %.0f%%" % (w["uncommon"] * 100))
	if w.get("rare", 0.0) > 0.0:
		parts.append("Rare %.0f%%" % (w["rare"] * 100))
	if w.get("legendary", 0.0) > 0.0:
		parts.append("Legendary %.0f%%" % (w["legendary"] * 100))
	return "  /  ".join(parts)
