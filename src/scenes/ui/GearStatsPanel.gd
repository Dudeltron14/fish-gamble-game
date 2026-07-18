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

const TIER_COMMON_ICON := preload("res://assets/ui_icons/icon_tier_common.png")
const TIER_UNCOMMON_ICON := preload("res://assets/ui_icons/icon_tier_uncommon.png")
const TIER_RARE_ICON := preload("res://assets/ui_icons/icon_tier_rare.png")
const TIER_LEGENDARY_ICON := preload("res://assets/ui_icons/icon_tier_legendary.png")
const MAGNET_TRASH_ICON := preload("res://assets/User_Gen_ChatGPT/Fish/junk_boot.png")
const MAGNET_CHEST_ICON := preload("res://assets/User_Gen_ChatGPT/Fish/overflowing_gold_chest.png")
const MAGNET_KEY_ICON := preload("res://assets/User_Gen_ChatGPT/Fish/ancient_key.png")
var _expanded := false
var _expanded_bottom := 0.0
var _vbox: VBoxContainer
var _shop_mode := false
var _flash_tween: Tween
var _flash_labels: Array[Label] = []

func _ready() -> void:
	ClientSettings.register_ui_scale_target(panel, Vector2(1.0, 0.0))
	_vbox = $Panel/Margin/VBox
	_expanded_bottom = panel.offset_bottom
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

func _set_expanded(expand: bool) -> void:
	_expanded = expand
	# Index 0 = Title label — always visible. Hide everything else when collapsed.
	for i in range(1, _vbox.get_child_count()):
		_vbox.get_child(i).visible = expand
	if not _shop_mode:
		call_deferred("_resize_panel", expand)

func _resize_panel(expand: bool) -> void:
	panel.offset_bottom = _expanded_bottom if expand else panel.offset_top + panel.get_combined_minimum_size().y

func is_expanded() -> bool:
	return _expanded

func set_expanded(expand: bool) -> void:
	_set_expanded(expand)

func configure_for_shop() -> void:
	_shop_mode = true
	layer = 11
	if is_node_ready():
		_apply_shop_mode()

func flash_slot(slot: String) -> void:
	_clear_flash()
	var labels: Array[Label] = []
	match slot:
		"rod": labels = [rod_header_lbl, cast_lbl, reel_lbl, rarity_bonus_lbl]
		"bait": labels = [bait_header_lbl, bite_lbl, common_lbl, uncommon_lbl, rare_lbl, legendary_lbl]
		"tackle": labels = [hook_header_lbl, durability_lbl, coin_lbl, react_lbl]
		_: return
	for label in labels:
		var highlight := StyleBoxFlat.new()
		highlight.bg_color = Color(1.0, 0.78, 0.12, 0.32)
		highlight.border_width_left = 1
		highlight.border_width_top = 1
		highlight.border_width_right = 1
		highlight.border_width_bottom = 1
		highlight.border_color = Color(1.0, 0.9, 0.35, 0.9)
		highlight.corner_radius_top_left = 2
		highlight.corner_radius_top_right = 2
		highlight.corner_radius_bottom_left = 2
		highlight.corner_radius_bottom_right = 2
		highlight.content_margin_left = 2
		highlight.content_margin_right = 2
		label.add_theme_stylebox_override("normal", highlight)
	_flash_labels = labels
	_flash_tween = create_tween()
	_flash_tween.tween_interval(2.4)
	_flash_tween.tween_callback(_clear_flash)

func _clear_flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	for label in _flash_labels:
		if is_instance_valid(label):
			label.remove_theme_stylebox_override("normal")
	_flash_labels.clear()

func _apply_shop_mode() -> void:
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_expanded(get_viewport().get_visible_rect().size.x >= 980.0)

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
	if tackle and tackle.id == "treasure_magnet":
		common_icon.texture = MAGNET_TRASH_ICON
		uncommon_icon.texture = MAGNET_CHEST_ICON
		rare_icon.texture = MAGNET_KEY_ICON
		legendary_icon.texture = TIER_LEGENDARY_ICON
		for icon: TextureRect in [common_icon, uncommon_icon, rare_icon, legendary_icon]:
			icon.modulate = Color.WHITE
		for label: Label in [common_lbl, uncommon_lbl, rare_lbl, legendary_lbl]:
			label.modulate = Color.WHITE
		bait_header_lbl.text = "MAGNET MODE: Bait incompatible"
		bite_lbl.text = "Trash / Chest / Key / Legend."
		common_lbl.text    = "45%"
		uncommon_lbl.text  = "27.5%"
		rare_lbl.text      = "27.5%"
		legendary_lbl.text = "0%"
		_tip(bait_icon, bait_header_lbl, "Treasure Magnet unequips bait and searches only for trash, Sunken Chests, or Ancient Keys.")
		_tip(bite_icon, bite_lbl, "One magnet durability is used per search. Every search has a 55%% chance to find a Chest or Key.")
		_tip(common_icon, common_lbl, "Trash: Old Boot, Tin Can, or Seaweed. This is the normal result when a treasure roll misses.")
		_tip(uncommon_icon, uncommon_lbl, "Sunken Chest: each search has a 27.5%% chance to find one.")
		_tip(rare_icon, rare_lbl, "Ancient Key: each search has a 27.5%% chance to find one. Chest and Key are equally likely.")
		_tip(legendary_icon, legendary_lbl, "Legendary fish cannot be caught while the Treasure Magnet is equipped.")
	else:
		common_icon.texture = TIER_COMMON_ICON
		uncommon_icon.texture = TIER_UNCOMMON_ICON
		rare_icon.texture = TIER_RARE_ICON
		legendary_icon.texture = TIER_LEGENDARY_ICON
		common_icon.modulate = Color(0.7, 0.7, 0.7)
		uncommon_icon.modulate = Color(0.4, 0.9, 0.4)
		rare_icon.modulate = Color(0.4, 0.6, 1.0)
		legendary_icon.modulate = Color(1.0, 0.8, 0.2)
		common_lbl.modulate = Color(0.7, 0.7, 0.7)
		uncommon_lbl.modulate = Color(0.4, 0.9, 0.4)
		rare_lbl.modulate = Color(0.4, 0.6, 1.0)
		legendary_lbl.modulate = Color(1.0, 0.8, 0.2)
		if bait:
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
			_tip(common_icon,    common_lbl,    "Starter Common fish: 35-65%% (no bait)\nBetter casts reduce junk and increase this range.\nBuy a Worm to unlock starter Uncommon fish.")
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
			coin_lbl.text = "Treasure  55% / use"
			react_lbl.text = "Trash 45%  •  Chest/Key 27.5%"
			_tip(coin_icon, coin_lbl, "Every Magnet search has a 55%% chance to find a Chest or Key.")
			_tip(react_icon, react_lbl, "Each search yields trash, a Sunken Chest, or an Ancient Key. Chest and Key are equally likely; it cannot catch legendary fish.")
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
