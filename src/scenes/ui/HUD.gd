extends CanvasLayer

@onready var coins_label: Label    = %CoinsLabel
@onready var equipped_label: Label = %EquippedLabel
@onready var context_hint: Label   = %ContextHint
@onready var bait_warning_label: Label = %WarningLabel
@onready var hook_warning_label: Label = %HookWarningLabel
@onready var catch_warning_label: Label = %CatchWarningLabel
@onready var catch_bar: HBoxContainer = %CatchBar

const CATCH_SLOT_SIZE := Vector2(40, 40)

var _warning_clear_token := 0
var _last_hook_durability := -1
var _last_hook_max := 0
var _has_seen_hook_state := false
var _catch_slot_icons: Array[TextureRect] = []
var _catch_slot_value_labels: Array[Label] = []

func _ready() -> void:
	ClientSettings.register_ui_scale_target($TopPanel, Vector2.ZERO)
	ClientSettings.register_ui_scale_target(context_hint, Vector2(0.5, 1.0))
	ClientSettings.register_ui_scale_target(bait_warning_label, Vector2(0.5, 0.0))
	ClientSettings.register_ui_scale_target(hook_warning_label, Vector2(0.5, 0.0))
	ClientSettings.register_ui_scale_target(%SettingsBtn, Vector2(1.0, 0.0))
	_style_context_hint()
	_style_warning_label(bait_warning_label)
	_style_warning_label(hook_warning_label)
	_style_warning_label(catch_warning_label)
	_build_catch_bar()
	GameManager.coins_changed.connect(_on_coins_changed)
	GameManager.zone_hint_changed.connect(_on_zone_hint_changed)
	GameManager.equipped_changed.connect(_refresh_equipped)
	GameManager.owned_changed.connect(_refresh_equipped)
	GameManager.hook_durability_changed.connect(_on_hook_durability_changed)
	GameManager.fishing_result_completed.connect(_hide_warnings_after_fishing_result)
	GameManager.catch_inventory_changed.connect(_on_catch_inventory_changed)
	NetAPI.bait_empty.connect(func(): _show_warning(bait_warning_label, "Bait ran out. Buy or equip more bait."))
	NetAPI.hook_broken.connect(func(): _show_warning(hook_warning_label, "Hook broke. Buy or equip another hook."))
	%SettingsBtn.pressed.connect(func(): ClientSettings.open(self))
	NetAPI.catch_inventory_full.connect(func(): _show_warning(catch_warning_label, "Catch bag full! Sell fish at the shop."))
	_on_coins_changed(GameManager.current_coins)
	_refresh_equipped()
	_refresh_catch_bar()

func _on_coins_changed(amount: int) -> void:
	coins_label.text = "Coins: %d" % amount

func _on_zone_hint_changed(hint: String) -> void:
	context_hint.text = hint
	context_hint.visible = hint != ""

func _on_hook_durability_changed(current: int, max_val: int) -> void:
	if _has_seen_hook_state \
			and _last_hook_durability == 1 \
			and current > _last_hook_durability \
			and max_val == _last_hook_max:
		_show_warning(hook_warning_label, "Hook broke. Next owned hook auto-equipped.")
	_last_hook_durability = current
	_last_hook_max = max_val
	_has_seen_hook_state = true
	_refresh_equipped()

func _refresh_equipped() -> void:
	var rod    := ItemRegistry.get_item(GameManager.equipped_rod_id)
	var bait   := ItemRegistry.get_item(GameManager.equipped_bait_id)
	var tackle := ItemRegistry.get_item(GameManager.equipped_tackle_id)

	var rod_text    := rod.display_name if rod else "—"
	var bait_text   := _consumable_text(bait, GameManager.equipped_bait_id)
	var hook_text   := _hook_text(tackle)

	equipped_label.text = "Rod: %s  Bait: %s  Hook: %s" % [rod_text, bait_text, hook_text]

func _consumable_text(item: ItemData, item_id: String) -> String:
	if item == null:
		return "—"
	return "%s ×%d" % [item.display_name, GameManager.get_owned(item_id)]

func _hook_text(tackle: TackleData) -> String:
	if tackle == null:
		return "—"
	var cur := GameManager.hook_durability
	var max_val := GameManager.hook_max_durability
	if max_val <= 0:
		return tackle.display_name
	return "%s %d/%d" % [tackle.display_name, cur, max_val]

func _style_context_hint() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.08, 0.04, 0.78)
	style.border_color = Color(0.68, 0.92, 0.70, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	context_hint.add_theme_stylebox_override("normal", style)
	context_hint.add_theme_font_size_override("font_size", 19)

func _style_warning_label(label: Label) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.20, 0.03, 0.02, 0.84)
	style.border_color = Color(1.0, 0.28, 0.18, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	label.add_theme_stylebox_override("normal", style)
	label.add_theme_font_size_override("font_size", 16)

func _show_warning(label: Label, message: String) -> void:
	_warning_clear_token += 1
	label.text = message
	label.visible = true

func _on_catch_inventory_changed() -> void:
	if catch_warning_label.visible and not GameManager.catch_inventory_is_full():
		catch_warning_label.visible = false
	_refresh_catch_bar()

func _build_catch_bar() -> void:
	for i in GameManager.MAX_CATCH_SLOTS:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = CATCH_SLOT_SIZE
		slot.add_theme_stylebox_override("panel", _make_catch_slot_style())

		var content := Control.new()
		content.custom_minimum_size = CATCH_SLOT_SIZE
		slot.add_child(content)

		var icon := TextureRect.new()
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.offset_left = 4
		icon.offset_top = 4
		icon.offset_right = -4
		icon.offset_bottom = -4
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		content.add_child(icon)

		var value_lbl := Label.new()
		value_lbl.anchor_left = 1.0
		value_lbl.anchor_top = 1.0
		value_lbl.anchor_right = 1.0
		value_lbl.anchor_bottom = 1.0
		value_lbl.offset_right = -2
		value_lbl.offset_bottom = -1
		value_lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		value_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
		value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_lbl.add_theme_font_size_override("font_size", 9)
		value_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		value_lbl.add_theme_constant_override("outline_size", 2)
		content.add_child(value_lbl)

		catch_bar.add_child(slot)
		_catch_slot_icons.append(icon)
		_catch_slot_value_labels.append(value_lbl)

func _refresh_catch_bar() -> void:
	var slots := GameManager.catch_inventory
	for i in _catch_slot_icons.size():
		var icon := _catch_slot_icons[i]
		var value_lbl := _catch_slot_value_labels[i]
		if i >= slots.size():
			icon.texture = null
			icon.tooltip_text = "Empty slot"
			value_lbl.text = ""
			continue
		var slot: Dictionary = slots[i]
		var fish := ItemRegistry.get_item(str(slot.fish_id)) as FishData
		icon.texture = fish.icon if fish else null
		icon.tooltip_text = "%s — %d coins" % [fish.display_name if fish else str(slot.fish_id), int(slot.sell_value)]
		value_lbl.text = str(int(slot.sell_value))

func _make_catch_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.03, 0.75)
	style.border_color = Color(0.62, 0.45, 0.25, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style

func _hide_warnings_after_fishing_result() -> void:
	if not bait_warning_label.visible and not hook_warning_label.visible:
		return
	_warning_clear_token += 1
	var token := _warning_clear_token
	await get_tree().create_timer(3.0).timeout
	if token == _warning_clear_token:
		bait_warning_label.visible = false
		hook_warning_label.visible = false
