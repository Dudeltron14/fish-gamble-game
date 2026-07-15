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

const SETTINGS_FILE := "user://settings.cfg"
var _expanded := false
var _music_vol := 80.0
var _sfx_vol   := 80.0
var _camera_zoom := 2.0
var _vbox: VBoxContainer
var _shop_mode := false
var _music_slider: HSlider
var _sfx_slider: HSlider
var _zoom_slider: HSlider
var _zoom_value_lbl: Label

func _ready() -> void:
	_vbox = $Panel/Margin/VBox
	_build_settings_section()
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
	if _shop_mode:
		_apply_shop_mode.call_deferred()

func _build_settings_section() -> void:
	var sep := HSeparator.new()
	_vbox.add_child(sep)

	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 8)
	var music_lbl := Label.new()
	music_lbl.text = "Music"
	music_lbl.custom_minimum_size = Vector2(40, 0)
	music_lbl.add_theme_font_size_override("font_size", 11)
	_music_slider = HSlider.new()
	_music_slider.name = "MusicSlider"
	_music_slider.min_value = 0.0
	_music_slider.max_value = 100.0
	_music_slider.step = 1.0
	_music_slider.value = _music_vol
	_music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_slider.focus_mode = Control.FOCUS_NONE  # prevent Tab key capture
	_music_slider.value_changed.connect(_on_music_changed)
	music_row.add_child(music_lbl)
	music_row.add_child(_music_slider)
	_vbox.add_child(music_row)

	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 8)
	var sfx_lbl := Label.new()
	sfx_lbl.text = "SFX"
	sfx_lbl.custom_minimum_size = Vector2(40, 0)
	sfx_lbl.add_theme_font_size_override("font_size", 11)
	_sfx_slider = HSlider.new()
	_sfx_slider.name = "SFXSlider"
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 100.0
	_sfx_slider.step = 1.0
	_sfx_slider.value = _sfx_vol
	_sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sfx_slider.focus_mode = Control.FOCUS_NONE  # prevent Tab key capture
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	sfx_row.add_child(sfx_lbl)
	sfx_row.add_child(_sfx_slider)
	_vbox.add_child(sfx_row)

	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 8)
	var zoom_lbl := Label.new()
	zoom_lbl.text = "View Zoom"
	zoom_lbl.custom_minimum_size = Vector2(64, 0)
	zoom_lbl.add_theme_font_size_override("font_size", 11)
	_zoom_slider = HSlider.new()
	_zoom_slider.name = "ZoomSlider"
	_zoom_slider.min_value = 1.0
	_zoom_slider.max_value = 4.0
	_zoom_slider.step = 0.25
	_zoom_slider.value = _camera_zoom
	_zoom_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zoom_slider.focus_mode = Control.FOCUS_NONE
	_zoom_slider.value_changed.connect(_on_zoom_changed)
	_zoom_value_lbl = Label.new()
	_zoom_value_lbl.custom_minimum_size = Vector2(38, 0)
	_zoom_value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_zoom_value_lbl.add_theme_font_size_override("font_size", 11)
	zoom_row.add_child(zoom_lbl)
	zoom_row.add_child(_zoom_slider)
	zoom_row.add_child(_zoom_value_lbl)
	_vbox.add_child(zoom_row)
	_refresh_zoom_label()

func _on_music_changed(value: float) -> void:
	_music_vol = value
	AudioManager.set_music_volume(value / 100.0)
	_save_settings()

func _on_sfx_changed(value: float) -> void:
	_sfx_vol = value
	AudioManager.set_sfx_volume(value / 100.0)
	_save_settings()

func _on_zoom_changed(value: float) -> void:
	_camera_zoom = value
	GameManager.set_camera_zoom(value)
	_refresh_zoom_label()
	_save_settings()

func _set_expanded(expand: bool) -> void:
	_expanded = expand
	# Index 0 = Title label — always visible. Hide everything else when collapsed.
	for i in range(1, _vbox.get_child_count()):
		_vbox.get_child(i).visible = expand

func is_expanded() -> bool:
	return _expanded

func set_expanded(expand: bool) -> void:
	_set_expanded(expand)

func configure_for_shop() -> void:
	_shop_mode = true
	layer = 11
	if is_node_ready():
		_apply_shop_mode()

func _apply_shop_mode() -> void:
	panel.offset_left = -258.0
	panel.offset_top = 16.0
	panel.offset_right = -8.0
	panel.offset_bottom = 16.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_expanded(get_viewport().get_visible_rect().size.x >= 980.0)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("audio", "music_volume", _music_vol)
	cfg.set_value("audio", "sfx_volume",   _sfx_vol)
	cfg.save(SETTINGS_FILE)
	var zoom_cfg := ConfigFile.new()
	zoom_cfg.set_value("gameplay", "camera_zoom", _camera_zoom)
	zoom_cfg.save(_zoom_settings_file())

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) == OK:
		_music_vol = cfg.get_value("audio", "music_volume", 80.0)
		_sfx_vol   = cfg.get_value("audio", "sfx_volume",   80.0)
	var zoom_cfg := ConfigFile.new()
	if zoom_cfg.load(_zoom_settings_file()) == OK:
		_camera_zoom = zoom_cfg.get_value("gameplay", "camera_zoom", 2.0)
	AudioManager.set_music_volume(_music_vol / 100.0)
	AudioManager.set_sfx_volume(_sfx_vol / 100.0)
	GameManager.set_camera_zoom(_camera_zoom)
	_sync_settings_controls()

func _zoom_settings_file() -> String:
	return "user://zoom_%s.cfg" % GameManager.current_player_name

func _sync_settings_controls() -> void:
	if _music_slider:
		_music_slider.set_value_no_signal(_music_vol)
	if _sfx_slider:
		_sfx_slider.set_value_no_signal(_sfx_vol)
	if _zoom_slider:
		_zoom_slider.set_value_no_signal(_camera_zoom)
	_refresh_zoom_label()

func _refresh_zoom_label() -> void:
	if _zoom_value_lbl:
		_zoom_value_lbl.text = "%d%%" % int(round(_camera_zoom * 100.0))

func _tip(icon: TextureRect, lbl: Label, text: String) -> void:
	icon.tooltip_text = text
	lbl.tooltip_text  = text

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _expanded:
		_set_expanded(false)
		get_viewport().set_input_as_handled()
		return
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
	if tackle and tackle.id == "treasure_magnet":
		bait_header_lbl.text = "MAGNET MODE: Bait incompatible"
		bite_lbl.text = "Treasure search  10 uses"
		common_lbl.text    = "Trash  94%"
		uncommon_lbl.text  = "Treasure (Chest/Key)  6%"
		rare_lbl.text      = "Legendary fish  0%"
		legendary_lbl.text = "Bait  incompatible"
		_tip(bait_icon, bait_header_lbl, "Treasure Magnet unequips bait and searches only for trash, Sunken Chests, or Ancient Keys.")
		_tip(bite_icon, bite_lbl, "One magnet durability is used per search. A full 10-use Magnet has a 45%% chance to find at least one Chest or Key.")
		_tip(common_icon, common_lbl, "Trash: Old Boot, Tin Can, or Seaweed. This is the normal result when a treasure roll misses.")
		_tip(uncommon_icon, uncommon_lbl, "Treasure: each search has about a 6%% chance to find a Sunken Chest or Ancient Key. Chest and Key are equally likely.")
		_tip(rare_icon, rare_lbl, "Legendary fish cannot be caught while the Treasure Magnet is equipped.")
		_tip(legendary_icon, legendary_lbl, "Bait cannot be equipped with the Treasure Magnet. Equip another hook to fish normally.")
	elif bait:
		var owned    := GameManager.get_owned(bait.id)
		var wait_pct := int((1.0 - bait.wait_modifier) * 100.0)
		bait_header_lbl.text = "BAIT: %s  x%d" % [bait.display_name, owned]
		bite_lbl.text = "Bite wait  -%d%%" % wait_pct
		_tip(bite_icon, bite_lbl, "Bite Wait  -%d%%\nReduces how long you wait after casting before a fish bites.\nStacks with cast quality — a perfect cast reduces it further.\nConsumed on every bite, win or lose." % wait_pct)
		if bait.id == "worm":
			common_lbl.text    = "69-70%"
			uncommon_lbl.text  = "18-28%"
			rare_lbl.text      = "0%"
			legendary_lbl.text = "0%"
			_tip(common_icon,    common_lbl,    "Starter Common fish: 69-70%%\nWorms can still find 3-12%% junk depending on cast quality.")
			_tip(uncommon_icon,  uncommon_lbl,  "Starter Uncommon fish: 18-28%%\nBetter casts improve these odds.")
			_tip(rare_icon,      rare_lbl,      "Rare fish: 0%%\nUse Glow Grub or better bait.")
			_tip(legendary_icon, legendary_lbl, "Legendary fish: 0%%\nNeeds Magic Bait for a meaningful chance.")
		else:
			var w := bait.rarity_weights
			common_lbl.text    = "%d%%" % int(w.get("common",    0.0) * 100)
			uncommon_lbl.text  = "%d%%" % int(w.get("uncommon",  0.0) * 100)
			rare_lbl.text      = "%d%%" % int(w.get("rare",      0.0) * 100)
			legendary_lbl.text = "%d%%" % int(w.get("legendary", 0.0) * 100)
			_tip(common_icon,    common_lbl,    "Common fish chance: %d%%\nLowest payout (9c base). Wide catch zone, slow fish, forgiving.\nJunk is excluded when bait uses normal rarity pools." % int(w.get("common", 0.0) * 100))
			_tip(uncommon_icon,  uncommon_lbl,  "Uncommon fish chance: %d%%\nModerate payout (20c base). Slightly harder minigame." % int(w.get("uncommon", 0.0) * 100))
			_tip(rare_icon,      rare_lbl,      "Rare fish chance: %d%%\nGood payout (56-73c). Smaller zone, faster fish, tighter escape timer." % int(w.get("rare", 0.0) * 100))
			_tip(legendary_icon, legendary_lbl, "Legendary fish chance: %d%%\nHighest payout (280c+). Tiny zone, max speed, brutal escape timer.\nRequires skill and good gear." % int(w.get("legendary", 0.0) * 100))
	else:
		bait_header_lbl.text = "BAIT: None"
		bite_lbl.text = "Bite wait  —"
		_tip(bite_icon, bite_lbl, "No bait equipped.\nWithout bait: 35-65%% junk depending on cast quality; otherwise starter Common fish.\nNo Uncommon, Rare, or Legendary fish are possible without bait.")
		common_lbl.text    = "35-65%"
		uncommon_lbl.text  = "0%"
		rare_lbl.text      = "0%"
		legendary_lbl.text = "0%"
		_tip(common_icon,    common_lbl,    "Starter Common fish: 35-65%% (no bait)\nBetter casts reduce junk and increase this range.\nBuy a Worm to unlock Uncommon starter fish.")
		_tip(uncommon_icon,  uncommon_lbl,  "Uncommon fish: 0%% (no bait)\nBuy a Worm to unlock starter Uncommon fish.")
		_tip(rare_icon,      rare_lbl,      "Rare fish: 0%%\nNeeds Glow Grub or better bait.")
		_tip(legendary_icon, legendary_lbl, "Legendary fish: 0%%\nNeeds Magic Bait for a meaningful chance.")

	# ── Hook ─────────────────────────────────────────────────────────────────
	_tip(hook_icon, hook_header_lbl, "Your equipped hook.\nMultiplies coin payouts, extends your react window, and has limited durability.\nLoses 1 durability per bite. Breaks when depleted — next owned hook auto-equips.")
	if tackle:
		var cur   := GameManager.hook_durability
		var max_v := GameManager.hook_max_durability
		hook_header_lbl.text = "HOOK: %s" % tackle.display_name
		durability_lbl.text = "Durability  %d / %d" % [cur, max_v]
		_tip(durability_icon, durability_lbl, "Durability  %d / %d\nUses remaining before this hook breaks.\nOne use lost per bite (win or lose).\nWhen it reaches 0, one hook is consumed from inventory and the next auto-equips at full durability." % [cur, max_v])
		if tackle.id == "treasure_magnet":
			coin_lbl.text = "Treasure  45% / 10 uses"
			react_lbl.text = "Trash 94%  •  Chest/Key 6%"
			_tip(coin_icon, coin_lbl, "Across its 10 uses, the Treasure Magnet has a 45%% chance to find at least one Chest or Key.")
			_tip(react_icon, react_lbl, "Each search yields either trash or an equal-odds Sunken Chest / Ancient Key. It cannot catch legendary fish.")
		else:
			coin_lbl.text = "Coins  x%.1f" % tackle.coin_multiplier
			_tip(coin_icon, coin_lbl, "Coin Multiplier  x%.1f\nAll fish payouts are multiplied by this value.\nExample: Kraken (650c base) → %dc with this hook." % [tackle.coin_multiplier, int(650.0 * tackle.coin_multiplier)])
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
