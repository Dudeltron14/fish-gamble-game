extends CanvasLayer

signal completed

@onready var coins_label: Label = %CoinsLabel
@onready var item_list: VBoxContainer = %ItemList
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	NetAPI.shop_result.connect(_on_shop_result)
	NetAPI.equip_result.connect(_on_equip_result)
	GameManager.owned_changed.connect(_populate.call_deferred)
	$Center/Panel/Margin/VBox/CloseBtn.pressed.connect(_close)
	AudioManager.set_music_context("shop")
	coins_label.text = "Coins: %d" % GameManager.current_coins
	_populate()

func _populate() -> void:
	for child in item_list.get_children():
		child.free()

	var shop_items: Array = []
	shop_items.append_array(ItemRegistry.rods.values())
	shop_items.append_array(ItemRegistry.baits.values())
	shop_items.append_array(ItemRegistry.tackle.values())
	shop_items = shop_items.filter(func(i: ItemData) -> bool: return i.buy_price > 0)
	shop_items.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.buy_price < b.buy_price)
	for item in shop_items:
		item_list.add_child(_make_row(item))

func _make_row(item: ItemData) -> Control:
	var owned := GameManager.get_owned(item.id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	var qty := (item as BaitData).uses_per_stack if item is BaitData else 1
	name_lbl.text = "%s ×%d" % [item.display_name, qty] if qty > 1 else item.display_name
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item.description
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.modulate = Color(0.75, 0.75, 0.75)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_lbl)

	var owned_lbl := Label.new()
	owned_lbl.text = "Owned: %d" % owned
	owned_lbl.add_theme_font_size_override("font_size", 10)
	owned_lbl.modulate = Color(0.55, 0.85, 0.55) if owned > 0 else Color(0.55, 0.55, 0.55)
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
		btn.pressed.connect(_on_buy_pressed.bind(item.id, btn))
		row.add_child(btn)

	if item is RodData or item is BaitData or item is TackleData:
		var equip_btn := Button.new()
		equip_btn.text = "Equip"
		equip_btn.custom_minimum_size = Vector2(52, 0)
		equip_btn.disabled = owned <= 0
		equip_btn.pressed.connect(_on_equip_pressed.bind(item.id))
		row.add_child(equip_btn)

	var sep := HSeparator.new()
	var wrapper := VBoxContainer.new()
	wrapper.add_child(row)
	wrapper.add_child(sep)
	return wrapper

func _on_buy_pressed(item_id: String, btn: Button) -> void:
	btn.disabled = true
	status_label.text = "Buying…"
	NetAPI.rpc("c2s_shop_buy", item_id)

func _on_equip_pressed(item_id: String) -> void:
	status_label.text = "Equipping…"
	NetAPI.rpc("c2s_equip", item_id)

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
		AudioManager.sfx("sfx_equip")
	else:
		status_label.text = "You don't own that item."
		status_label.modulate = Color(1.0, 0.4, 0.4)

func _on_shop_result(ok: bool, reason: String, new_balance: int) -> void:
	GameManager.set_coins(new_balance)
	coins_label.text = "Coins: %d" % new_balance
	status_label.text = reason
	status_label.modulate = Color(0.3, 1.0, 0.4) if ok else Color(1.0, 0.4, 0.4)
	if ok:
		AudioManager.sfx("sfx_buy")
	else:
		AudioManager.sfx("sfx_not_enough_coins")
	_populate.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()

func _close() -> void:
	AudioManager.set_music_context("world")
	completed.emit()
	queue_free()
