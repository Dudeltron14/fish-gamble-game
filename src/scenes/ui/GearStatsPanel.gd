extends CanvasLayer

@onready var panel: PanelContainer = $Panel

# Rod
@onready var rod_icon:          TextureRect = %RodIcon
@onready var rod_header_lbl:    Label       = %RodHeaderLabel
@onready var cast_icon:         TextureRect = %CastIcon
@onready var cast_lbl:          Label       = %CastLabel
@onready var reel_icon:         TextureRect = %ReelIcon
@onready var reel_lbl:          Label       = %ReelLabel
@onready var rarity_bonus_icon: TextureRect = %RarityBonusIcon
@onready var rarity_bonus_lbl:  Label       = %RarityBonusLabel

# Bait
@onready var bait_icon:       TextureRect = %BaitIcon
@onready var bait_header_lbl: Label       = %BaitHeaderLabel
@onready var bite_icon:       TextureRect = %BiteIcon
@onready var bite_lbl:        Label       = %BiteLabel
@onready var common_icon:     TextureRect = %CommonIcon
@onready var common_lbl:      Label       = %CommonLabel
@onready var uncommon_icon:   TextureRect = %UncommonIcon
@onready var uncommon_lbl:    Label       = %UncommonLabel
@onready var rare_icon:       TextureRect = %RareIcon
@onready var rare_lbl:        Label       = %RareLabel
@onready var legendary_icon:  TextureRect = %LegendaryIcon
@onready var legendary_lbl:   Label       = %LegendaryLabel

# Hook
@onready var hook_icon:        TextureRect = %HookIcon
@onready var hook_header_lbl:  Label       = %HookHeaderLabel
@onready var durability_icon:  TextureRect = %DurabilityIcon
@onready var durability_lbl:   Label       = %DurabilityLabel
@onready var coin_icon:        TextureRect = %CoinIcon
@onready var coin_lbl:         Label       = %CoinLabel
@onready var react_icon:       TextureRect = %ReactIcon
@onready var react_lbl:        Label       = %ReactLabel

# Cast hint
@onready var cast_hint_icon: TextureRect = %CastHintIcon
@onready var cast_hint_lbl:  Label       = %CastHintLabel

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
		rod_header_lbl.text = "ROD: %s" % rod.display_name
		var cast_t  := 100.0 / (60.0 * rod.cast_speed)
		cast_lbl.text  = "Cast speed  x%.1f  (%.1fs fill)" % [rod.cast_speed, cast_t]
		var catch_t := 1.0 / (0.35 * rod.line_strength)
		reel_lbl.text  = "Reel speed  x%.1f  (%.1fs catch)" % [rod.line_strength, catch_t]
		if rod.rarity_bonus > 0.0:
			rarity_bonus_lbl.text = "Rarity bonus  +%d%%" % int(rod.rarity_bonus * 100)
		else:
			rarity_bonus_lbl.text = "Rarity bonus  none"
	else:
		rod_header_lbl.text    = "ROD: None"
		cast_lbl.text          = "Cast speed  x1.0"
		reel_lbl.text          = "Reel speed  x1.0"
		rarity_bonus_lbl.text  = "Rarity bonus  none"

	# ── Bait ─────────────────────────────────────────────────────────────────
	if bait:
		var owned    := GameManager.get_owned(bait.id)
		var wait_pct := int((1.0 - bait.wait_modifier) * 100.0)
		bait_header_lbl.text = "BAIT: %s  x%d" % [bait.display_name, owned]
		bite_lbl.text        = "Bite wait  -%d%%" % wait_pct
		var w := bait.rarity_weights
		common_lbl.text    = "%d%%" % int(w.get("common",    0.0) * 100)
		uncommon_lbl.text  = "%d%%" % int(w.get("uncommon",  0.0) * 100)
		rare_lbl.text      = "%d%%" % int(w.get("rare",      0.0) * 100)
		legendary_lbl.text = "%d%%" % int(w.get("legendary", 0.0) * 100)
	else:
		bait_header_lbl.text = "BAIT: None"
		bite_lbl.text        = "Bite wait  —"
		common_lbl.text      = "95%"
		uncommon_lbl.text    = "5%"
		rare_lbl.text        = "0%"
		legendary_lbl.text   = "0%"

	# ── Hook ─────────────────────────────────────────────────────────────────
	if tackle:
		var cur := GameManager.hook_durability
		var max_v := GameManager.hook_max_durability
		hook_header_lbl.text  = "HOOK: %s" % tackle.display_name
		durability_lbl.text   = "Durability  %d / %d" % [cur, max_v]
		coin_lbl.text         = "Coins  x%.1f" % tackle.coin_multiplier
		react_lbl.text        = "React window  +%d%%" % int(tackle.escape_reduction * 100)
	else:
		hook_header_lbl.text = "HOOK: None"
		durability_lbl.text  = "Durability  —"
		coin_lbl.text        = "Coins  x1.0"
		react_lbl.text       = "React window  +0%"
