extends CanvasLayer

signal completed

const GEAR_STATS_SCENE := preload("res://src/scenes/ui/GearStatsPanel.tscn")

@onready var coins_label: Label = %CoinsLabel
@onready var equipped_label: Label = %EquippedLabel
@onready var item_list: VBoxContainer = %ItemList
@onready var status_label: Label = %StatusLabel
@onready var rods_tab: Button = %RodsTab
@onready var bait_tab: Button = %BaitTab
@onready var tackle_tab: Button = %TackleTab
@onready var skins_tab: Button = %SkinsTab
@onready var bobbers_tab: Button = %BobbersTab

var _gear_stats_panel: CanvasLayer = null
var _category := "rods"
var _pending_buys: Array[Dictionary] = []

func _ready() -> void:
	ClientSettings.register_ui_scale_target($Center/Panel, Vector2(0.5, 0.5))
	NetAPI.shop_result.connect(_on_shop_result)
	NetAPI.equip_result.connect(_on_equip_result)
	GameManager.owned_changed.connect(_populate.call_deferred)
	GameManager.owned_changed.connect(_refresh_equipped)
	GameManager.equipped_changed.connect(_refresh_equipped)
	GameManager.hook_durability_changed.connect(func(_current: int, _max_val: int): _refresh_equipped())
	GameManager.coins_changed.connect(_on_coins_changed)
	$Center/Panel/Margin/VBox/CloseBtn.pressed.connect(_close)
	rods_tab.pressed.connect(_select_category.bind("rods"))
	bait_tab.pressed.connect(_select_category.bind("baits"))
	tackle_tab.pressed.connect(_select_category.bind("tackle"))
	skins_tab.pressed.connect(_select_category.bind("skins"))
	bobbers_tab.pressed.connect(_select_category.bind("bobbers"))
	AudioManager.set_music_context("shop")
	coins_label.text = "Coins: %d" % GameManager.current_coins
	_refresh_equipped()
	_add_gear_stats_panel()
	_populate()
	call_deferred("_animate_open")

func _animate_open() -> void:
	var panel: Control = $Center/Panel
	panel.pivot_offset = panel.size * 0.5
	panel.modulate.a = 0.0
	panel.scale = Vector2.ONE * 0.96
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.12)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _populate() -> void:
	for child in item_list.get_children():
		child.free()

	if _category in ["skins", "bobbers"]:
		for item: Dictionary in CosmeticCatalog.get_category(_category):
			if not bool(item.get("default", false)):
				item_list.add_child(_make_cosmetic_row(item))
		return
	var shop_items: Array = ItemRegistry.get(_category).values()
	shop_items = shop_items.filter(func(i: ItemData) -> bool: return i.buy_price > 0)
	shop_items.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.buy_price < b.buy_price)
	for item in shop_items:
		item_list.add_child(_make_row(item))

func _select_category(category: String) -> void:
	_category = category
	rods_tab.disabled = category == "rods"
	bait_tab.disabled = category == "baits"
	tackle_tab.disabled = category == "tackle"
	skins_tab.disabled = category == "skins"
	bobbers_tab.disabled = category == "bobbers"
	_populate()

func _make_cosmetic_row(item: Dictionary) -> Control:
	var owned := GameManager.get_owned(str(item.id))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.texture = CosmeticCatalog.icon_for(item)
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = str(item.name)
	info.add_child(name_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = str(item.description)
	desc_lbl.add_theme_font_size_override("font_size", 17)
	desc_lbl.modulate = Color(0.75, 0.75, 0.75)
	info.add_child(desc_lbl)
	var owned_lbl := Label.new()
	owned_lbl.text = "Owned: %d" % owned
	owned_lbl.add_theme_font_size_override("font_size", 16)
	owned_lbl.modulate = Color(0.55, 0.85, 0.55) if owned > 0 else Color(0.65, 0.65, 0.65)
	info.add_child(owned_lbl)
	row.add_child(info)
	var price := int(item.price)
	var price_lbl := Label.new()
	price_lbl.text = "%d c" % price
	price_lbl.custom_minimum_size = Vector2(52, 0)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(price_lbl)
	var buy := Button.new()
	buy.text = "Owned" if owned > 0 else "Buy"
	buy.custom_minimum_size = Vector2(52, 0)
	buy.disabled = owned > 0 or GameManager.current_coins < price
	buy.pressed.connect(_on_buy_pressed.bind(str(item.id), buy))
	row.add_child(buy)
	var wrapper := VBoxContainer.new()
	wrapper.add_child(row)
	wrapper.add_child(HSeparator.new())
	return wrapper

func _make_row(item: ItemData) -> Control:
	var owned := GameManager.get_owned(item.id)
	var slot := _slot_for_item(item)
	var equipped := _is_equipped(item)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	if item.icon:
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	var qty := (item as BaitData).uses_per_stack if item is BaitData else 1
	var name_text := "%s ×%d" % [item.display_name, qty] if qty > 1 else item.display_name
	if equipped:
		name_text += "  [Equipped]"
	name_lbl.text = name_text
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item.description
	desc_lbl.add_theme_font_size_override("font_size", 17)
	desc_lbl.modulate = Color(0.75, 0.75, 0.75)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_lbl)

	var owned_lbl := Label.new()
	owned_lbl.text = "%s  Owned: %d" % [slot, owned] if not slot.is_empty() else "Owned: %d" % owned
	owned_lbl.add_theme_font_size_override("font_size", 16)
	owned_lbl.modulate = Color(0.55, 0.85, 0.55) if owned > 0 else Color(0.65, 0.65, 0.65)
	info.add_child(owned_lbl)

	row.add_child(info)

	var price_lbl := Label.new()
	price_lbl.text = "%d c" % item.buy_price
	price_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_lbl.custom_minimum_size = Vector2(52, 0)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price_lbl)

	if item.buy_price > 0:
		var btn := Button.new()
		btn.text = "Buy"
		btn.custom_minimum_size = Vector2(52, 0)
		btn.disabled = GameManager.current_coins < item.buy_price or (item is RodData and owned > 0)
		btn.pressed.connect(_on_buy_pressed.bind(item.id, btn))
		row.add_child(btn)

	if item is RodData or item is BaitData or item is TackleData:
		var equip_btn := Button.new()
		equip_btn.text = "Equipped" if equipped else "Equip"
		equip_btn.custom_minimum_size = Vector2(52, 0)
		equip_btn.disabled = owned <= 0 or equipped
		equip_btn.pressed.connect(_on_equip_pressed.bind(item.id, equip_btn))
		row.add_child(equip_btn)

	var sep := HSeparator.new()
	var wrapper := VBoxContainer.new()
	wrapper.add_child(row)
	wrapper.add_child(sep)
	return wrapper

func _on_buy_pressed(item_id: String, btn: Button) -> void:
	var purchase := _purchase_data(item_id)
	if purchase.is_empty() or GameManager.current_coins < int(purchase.price):
		return
	_pending_buys.append(purchase)
	GameManager.set_coins(GameManager.current_coins - int(purchase.price))
	GameManager.set_owned(item_id, GameManager.get_owned(item_id) + int(purchase.qty))
	status_label.text = "Purchased %s!" % str(purchase.name)
	status_label.modulate = Color(0.3, 1.0, 0.4)
	AudioManager.sfx("sfx_buy")
	_pulse(btn)
	NetAPI.rpc_id(1, "c2s_shop_buy", item_id)

func _on_equip_pressed(item_id: String, btn: Button) -> void:
	_pulse(btn)
	NetAPI.rpc_id(1, "c2s_equip", item_id)

func _pulse(control: Control) -> void:
	var tween := create_tween()
	tween.tween_property(control, "modulate", Color(1.0, 0.85, 0.35), 0.06)
	tween.tween_property(control, "modulate", Color.WHITE, 0.14)

func _on_equip_result(ok: bool, item_id: String, slot: String) -> void:
	if ok:
		var item := ItemRegistry.get_item(item_id)
		status_label.text = "Equipped %s!" % (item.display_name if item else item_id)
		status_label.modulate = Color(0.3, 1.0, 0.4)
		match slot:
			"rod":    GameManager.equipped_rod_id    = item_id
			"bait":   GameManager.equipped_bait_id   = item_id
			"tackle": GameManager.equipped_tackle_id = item_id
		GameManager.equipped_changed.emit()
		if _gear_stats_panel and _gear_stats_panel.has_method("flash_slot"):
			_gear_stats_panel.flash_slot(slot)
		AudioManager.sfx("sfx_equip")
		_populate.call_deferred()
	else:
		status_label.text = "You don't own that item."
		status_label.modulate = Color(1.0, 0.4, 0.4)

func _on_shop_result(ok: bool, reason: String, new_balance: int) -> void:
	var purchase: Dictionary = _pending_buys.pop_front() if not _pending_buys.is_empty() else {}
	var pending_cost := 0
	for pending: Dictionary in _pending_buys:
		pending_cost += int(pending.price)
	GameManager.set_coins(new_balance - pending_cost)
	if not ok and not purchase.is_empty():
		GameManager.set_owned(str(purchase.item_id), GameManager.get_owned(str(purchase.item_id)) - int(purchase.qty))
	elif not purchase.is_empty():
		var queued_qty := 0
		for pending: Dictionary in _pending_buys:
			if str(pending.item_id) == str(purchase.item_id):
				queued_qty += int(pending.qty)
		if queued_qty > 0:
			GameManager.set_owned(str(purchase.item_id), GameManager.get_owned(str(purchase.item_id)) + queued_qty)
	coins_label.text = "Coins: %d" % GameManager.current_coins
	status_label.text = reason
	status_label.modulate = Color(0.3, 1.0, 0.4) if ok else Color(1.0, 0.4, 0.4)
	if not ok:
		AudioManager.sfx("sfx_not_enough_coins")
	_populate.call_deferred()

func _purchase_data(item_id: String) -> Dictionary:
	var cosmetic := CosmeticCatalog.get_item(item_id)
	if not cosmetic.is_empty():
		return {"item_id": item_id, "price": int(cosmetic.price), "qty": 1, "name": str(cosmetic.name)}
	var item := ItemRegistry.get_item(item_id) as ItemData
	if item == null:
		return {}
	return {"item_id": item_id, "price": item.buy_price, "qty": (item as BaitData).uses_per_stack if item is BaitData else 1, "name": item.display_name}

func _on_coins_changed(new_balance: int) -> void:
	coins_label.text = "Coins: %d" % new_balance
	_populate.call_deferred()

func _refresh_equipped() -> void:
	equipped_label.text = GameManager.get_equipped_summary()

func _slot_for_item(item: ItemData) -> String:
	if item is RodData:
		return "Rod"
	if item is BaitData:
		return "Bait"
	if item is TackleData:
		return "Hook"
	return ""

func _is_equipped(item: ItemData) -> bool:
	if item is RodData:
		return GameManager.equipped_rod_id == item.id
	if item is BaitData:
		return GameManager.equipped_bait_id == item.id
	if item is TackleData:
		return GameManager.equipped_tackle_id == item.id
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("stats_toggle") and _gear_stats_panel:
		_gear_stats_panel.set_expanded(not _gear_stats_panel.is_expanded())
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	AudioManager.set_music_context("world")
	completed.emit()
	queue_free()

func _add_gear_stats_panel() -> void:
	_gear_stats_panel = GEAR_STATS_SCENE.instantiate()
	add_child(_gear_stats_panel)
	if _gear_stats_panel.has_method("configure_for_shop"):
		_gear_stats_panel.configure_for_shop()
