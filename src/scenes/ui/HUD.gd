extends CanvasLayer

@onready var coins_label: Label    = %CoinsLabel
@onready var equipped_label: Label = %EquippedLabel
@onready var context_hint: Label   = %ContextHint

func _ready() -> void:
	GameManager.coins_changed.connect(_on_coins_changed)
	GameManager.zone_hint_changed.connect(_on_zone_hint_changed)
	GameManager.equipped_changed.connect(_refresh_equipped)
	GameManager.owned_changed.connect(_refresh_equipped)
	_on_coins_changed(GameManager.current_coins)
	_refresh_equipped()

func _on_coins_changed(amount: int) -> void:
	coins_label.text = "Coins: %d" % amount

func _on_zone_hint_changed(hint: String) -> void:
	context_hint.text = hint
	context_hint.visible = hint != ""

func _refresh_equipped() -> void:
	var rod    := ItemRegistry.get_item(GameManager.equipped_rod_id)
	var bait   := ItemRegistry.get_item(GameManager.equipped_bait_id)
	var tackle := ItemRegistry.get_item(GameManager.equipped_tackle_id)

	var rod_text    := rod.display_name if rod else "—"
	var bait_text   := _gear_text(bait,   GameManager.equipped_bait_id)
	var tackle_text := _gear_text(tackle, GameManager.equipped_tackle_id)

	equipped_label.text = "Rod: %s  Bait: %s  Hook: %s" % [rod_text, bait_text, tackle_text]

func _gear_text(item: ItemData, item_id: String) -> String:
	if item == null:
		return "—"
	var qty := GameManager.get_owned(item_id)
	return "%s ×%d" % [item.display_name, qty]
