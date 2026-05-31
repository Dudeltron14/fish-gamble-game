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

@export var panel_bg_color: Color = Color(0.12, 0.14, 0.18, 1.0)
@export var panel_corner_radius: int = 4

const SETTINGS_FILE := "user://settings.cfg"
var _expanded := false
var _music_vol := 80.0
var _sfx_vol   := 80.0
var _vbox: VBoxContainer

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = panel_bg_color
	style.corner_radius_top_left    = panel_corner_radius
	style.corner_radius_top_right   = panel_corner_radius
	style.corner_radius_bottom_left = panel_corner_radius
	style.corner_radius_bottom_right = panel_corner_radius
	$Panel.add_theme_stylebox_override("panel", style)

	_vbox = $Panel/Margin/VBox
	_build_volume_section()
	_load_settings()
	_set_expanded(false)   # collapsed by default — only title shows

	for node: Control in [rod_icon, cast_icon, reel_icon, rarity_bonus_icon,
				 bait_icon, bite_icon, common_icon, uncommon_icon, rare_icon, legendary_icon,
				 hook_icon, durability_icon, coin_icon, react_icon, cast_hint_icon,
				 rod_header_lbl, cast_lbl, reel_lbl, rarity_bonus_lbl,
				 bait_header_lbl, bite_lbl, common_lbl, uncommon_lbl, rare_lbl, legendary_lbl,
				 hook_header_lbl, durability_lbl, coin_lbl, react_lbl, cast_hint_lbl]:
		node.mouse_filter = Control.MOUSE_FILTER_STOP

	GameManager.equipped_changed.connect(_refresh)
	GameManager.hook_durability_changed.connect(func(_c, _m): _refresh())
	GameManager.owned_changed.connect(_refresh)
	_refresh()

func _build_volume_section() -> void:
	var sep := HSeparator.new()
	_vbox.add_child(sep)

	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 8)
	var music_lbl := Label.new()
	music_lbl.text = "Music"
	music_lbl.custom_minimum_size = Vector2(40, 0)
	music_lbl.add_theme_font_size_override("font_size", 11)
	var music_slider := HSlider.new()
	music_slider.name = "MusicSlider"
	music_slider.min_value = 0.0
	music_slider.max_value = 100.0
	music_slider.step = 1.0
	music_slider.value = _music_vol
	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_slider.value_changed.connect(_on_music_changed)
	music_row.add_child(music_lbl)
	music_row.add_child(music_slider)
	_vbox.add_child(music_row)

	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 8)
	var sfx_lbl := Label.new()
	sfx_lbl.text = "SFX"
	sfx_lbl.custom_minimum_size = Vector2(40, 0)
	sfx_lbl.add_theme_font_size_override("font_size", 11)
	var sfx_slider := HSlider.new()
	sfx_slider.name = "SFXSlider"
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 100.0
	sfx_slider.step = 1.0
	sfx_slider.value = _sfx_vol
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.value_changed.connect(_on_sfx_changed)
	sfx_row.add_child(sfx_lbl)
	sfx_row.add_child(sfx_slider)
	_vbox.add_child(sfx_row)

func _on_music_changed(value: float) -> void:
	_music_vol = value
	AudioManager.set_volume(AudioManager.BUS_MUSIC,
		linear_to_db(maxf(value / 100.0, 0.0001)))
	_save_settings()

func _on_sfx_changed(value: float) -> void:
	_sfx_vol = value
	AudioManager.set_volume(AudioManager.BUS_SFX,
		linear_to_db(maxf(value / 100.0, 0.0001)))
	_save_settings()

func _set_expanded(expand: bool) -> void:
	_expanded = expand
	# Index 0 = Title label — always visible. Hide everything else when collapsed.
	for i in range(1, _vbox.get_child_count()):
		_vbox.get_child(i).visible = expand

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", _music_vol)
	cfg.set_value("audio", "sfx_volume",   _sfx_vol)
	cfg.save(SETTINGS_FILE)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) != OK:
		return
	_music_vol = cfg.get_value("audio", "music_volume", 80.0)
	_sfx_vol   = cfg.get_value("audio", "sfx_volume",   80.0)
	_on_music_changed(_music_vol)
	_on_sfx_changed(_sfx_vol)

func _tip(icon: TextureRect, lbl: Label, text: String) -> void:
	icon.tooltip_text = text
	lbl.tooltip_text  = text

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("stats_toggle"):
		_set_expanded(not _expanded)

func _refresh() -> void:
	var rod    := ItemRegistry.get_item(GameManager.equipped_rod_id)    as RodData
	var bait   := ItemRegistry.get_item(GameManager.equipped_bait_id)   as BaitData
	var tackle := ItemRegistry.get_item(GameManager.equipped_tackle_id) as TackleData

	# ── Rod ──────────────────────────────────────────────────────────────────
	_tip(rod_icon, rod_header_lbl, "Your equipped rod.\nAffects cast speed, reel speed, and rarity odds.")
	if rod:
		rod_header_lbl.text = "ROD: %s" % rod.display_name
		var cast_t := 100.0 / (60.0 * rod.cast_speed)
		cast_lbl.text = "Cast speed  x%.1f  (%.1fs fill)" % [rod.cast_speed, cast_t]
		_tip(cast_icon, cast_lbl, "Cast Speed  x%.1f\nHow fast the power bar fills while holding E.\nFull charge takes %.1f seconds.\nHigher = less time casting, more time fishing." % [rod.cast_speed, cast_t])
		var catch_t := 1.0 / (0.35 * rod.line_strength)
		reel_lbl.text = "Reel speed  x%.1f  (%.1fs catch)" % [rod.line_strength, catch_t]
		_tip(reel_icon, reel_lbl, "Reel Speed  x%.1f\nHow fast the catch meter fills when your cursor overlaps the fish.\nNeeds %.1f seconds of overlap to land a catch.\nHigher = more forgiving and faster catches." % [rod.line_strength, catch_t])
		if rod.rarity_bonus > 0.0:
			rarity_bonus_lbl.text = "Rarity bonus  +%d%%" % int(rod.rarity_bonus * 100)
			_tip(rarity_bonus_icon, rarity_bonus_lbl, "Rarity Bonus  +%d%%\nShifts fish odds away from Common toward Rare and Legendary.\nStacks with bait and cast quality.\nEffect: Common -%d%%,  Rare +%d%%,  Legendary +%d%%." % [int(rod.rarity_bonus*100), int(rod.rarity_bonus*100), int(rod.rarity_bonus*70), int(rod.rarity_bonus*30)])
		else:
			rarity_bonus_lbl.text = "Rarity bonus  none"
			_tip(rarity_bonus_icon, rarity_bonus_lbl, "Rarity Bonus: none\nThis rod does not improve rarity odds.\nUpgrade to Angler's Rod (+5%%) or Master Rod (+12%%) for a bonus.")
	else:
		rod_header_lbl.text = "ROD: None"
		cast_lbl.text = "Cast speed  x1.0"
		_tip(cast_icon, cast_lbl, "No rod equipped.")
		reel_lbl.text = "Reel speed  x1.0"
		_tip(reel_icon, reel_lbl, "No rod equipped.")
		rarity_bonus_lbl.text = "Rarity bonus  none"
		_tip(rarity_bonus_icon, rarity_bonus_lbl, "No rod equipped.")

	# ── Bait ─────────────────────────────────────────────────────────────────
	_tip(bait_icon, bait_header_lbl, "Your equipped bait.\nControls which fish rarities can appear and reduces bite wait time.\nConsumed once per bite regardless of outcome.")
	if bait:
		var owned    := GameManager.get_owned(bait.id)
		var wait_pct := int((1.0 - bait.wait_modifier) * 100.0)
		bait_header_lbl.text = "BAIT: %s  x%d" % [bait.display_name, owned]
		bite_lbl.text = "Bite wait  -%d%%" % wait_pct
		_tip(bite_icon, bite_lbl, "Bite Wait  -%d%%\nReduces how long you wait after casting before a fish bites.\nStacks with cast quality — a perfect cast reduces it further.\nConsumed on every bite, win or lose." % wait_pct)
		var w := bait.rarity_weights
		common_lbl.text    = "%d%%" % int(w.get("common",    0.0) * 100)
		uncommon_lbl.text  = "%d%%" % int(w.get("uncommon",  0.0) * 100)
		rare_lbl.text      = "%d%%" % int(w.get("rare",      0.0) * 100)
		legendary_lbl.text = "%d%%" % int(w.get("legendary", 0.0) * 100)
		_tip(common_icon,    common_lbl,    "Common fish chance: %d%%\nLowest payout (9c base). Wide catch zone, slow fish, forgiving." % int(w.get("common", 0.0) * 100))
		_tip(uncommon_icon,  uncommon_lbl,  "Uncommon fish chance: %d%%\nModerate payout (20c base). Slightly harder minigame." % int(w.get("uncommon", 0.0) * 100))
		_tip(rare_icon,      rare_lbl,      "Rare fish chance: %d%%\nGood payout (56–73c). Smaller zone, faster fish, tighter escape timer." % int(w.get("rare", 0.0) * 100))
		_tip(legendary_icon, legendary_lbl, "Legendary fish chance: %d%%\nHighest payout (280c+). Tiny zone, max speed, brutal escape timer.\nRequires skill and good gear." % int(w.get("legendary", 0.0) * 100))
	else:
		bait_header_lbl.text = "BAIT: None"
		bite_lbl.text = "Bite wait  —"
		_tip(bite_icon, bite_lbl, "No bait equipped.\nWithout bait: 95%% Common, 5%% Uncommon only.\nNo Rare or Legendary fish are possible without bait.")
		common_lbl.text    = "95%"
		uncommon_lbl.text  = "5%"
		rare_lbl.text      = "0%"
		legendary_lbl.text = "0%"
		_tip(common_icon,    common_lbl,    "Common fish: 95%% (no bait)\nBuy a Worm to unlock Rare fish.")
		_tip(uncommon_icon,  uncommon_lbl,  "Uncommon fish: 5%% (no bait)\nBuy a Worm to improve these odds.")
		_tip(rare_icon,      rare_lbl,      "Rare fish: 0%%\nNeeds at least a Worm equipped.")
		_tip(legendary_icon, legendary_lbl, "Legendary fish: 0%%\nNeeds Magic Bait for a meaningful chance.")

	# ── Hook ─────────────────────────────────────────────────────────────────
	_tip(hook_icon, hook_header_lbl, "Your equipped hook.\nMultiplies coin payouts, extends your react window, and has limited durability.\nLoses 1 durability per bite. Breaks when depleted — next owned hook auto-equips.")
	if tackle:
		var cur   := GameManager.hook_durability
		var max_v := GameManager.hook_max_durability
		hook_header_lbl.text = "HOOK: %s" % tackle.display_name
		durability_lbl.text = "Durability  %d / %d" % [cur, max_v]
		_tip(durability_icon, durability_lbl, "Durability  %d / %d\nUses remaining before this hook breaks.\nOne use lost per bite (win or lose).\nWhen it reaches 0, one hook is consumed from inventory and the next auto-equips at full durability." % [cur, max_v])
		coin_lbl.text = "Coins  x%.1f" % tackle.coin_multiplier
		_tip(coin_icon, coin_lbl, "Coin Multiplier  x%.1f\nAll fish payouts are multiplied by this value.\nExample: Kraken (280c base) → %dc with this hook." % [tackle.coin_multiplier, int(280.0 * tackle.coin_multiplier)])
		react_lbl.text = "React window  +%d%%" % int(tackle.escape_reduction * 100)
		_tip(react_icon, react_lbl, "React Window  +%d%%\nExtends the time you have to press E when a fish bites.\nCritical on hard fish — Kraken base react time is only 0.74s.\nWith this hook: %.2fs react window on Kraken." % [int(tackle.escape_reduction * 100), 0.74 * (1.0 + tackle.escape_reduction)])
	else:
		hook_header_lbl.text = "HOOK: None"
		durability_lbl.text = "Durability  —"
		_tip(durability_icon, durability_lbl, "No hook equipped.\nBuy a Basic Hook (15c) from the shop — it multiplies coin earnings and widens your react window.")
		coin_lbl.text = "Coins  x1.0"
		_tip(coin_icon, coin_lbl, "Coin Multiplier: x1.0 (no hook)\nEquip a hook to earn bonus coins per catch.")
		react_lbl.text = "React window  +0%"
		_tip(react_icon, react_lbl, "React Window: +0%% (no hook)\nEquip a hook to give yourself more time to react to bites.")

	# ── Cast hint ─────────────────────────────────────────────────────────────
	cast_hint_lbl.text = "Cast: perfect = Common -10%, Rare +7%, Legendary +3%"
	_tip(cast_hint_icon, cast_hint_lbl,
		"Cast Quality — how close to 100%% you release E.\n\n" +
		"Perfect cast (100%%):\n  Common -10%%,  Rare +7%%,  Legendary +3%%\n  Shorter bite wait,  wider react window.\n\n" +
		"Terrible cast (0%%):\n  Common +10%%,  Rare -7%%,  Legendary -3%%\n  Much longer wait,  shorter react window.")
