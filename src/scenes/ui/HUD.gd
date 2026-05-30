extends CanvasLayer

@onready var coins_label: Label   = %CoinsLabel
@onready var equipped_label: Label = %EquippedLabel
@onready var context_hint: Label  = %ContextHint

func _ready() -> void:
	GameManager.coins_changed.connect(_on_coins_changed)
	GameManager.zone_hint_changed.connect(_on_zone_hint_changed)
	GameManager.equipped_changed.connect(_refresh_equipped)
	_on_coins_changed(GameManager.current_coins)
	_refresh_equipped()

func _on_coins_changed(amount: int) -> void:
	coins_label.text = "Coins: %d" % amount

func _on_zone_hint_changed(hint: String) -> void:
	context_hint.text = hint
	context_hint.visible = hint != ""

func _refresh_equipped() -> void:
	var rod  := ItemRegistry.get_item(GameManager.equipped_rod_id)
	var bait := ItemRegistry.get_item(GameManager.equipped_bait_id)
	var rod_name  := rod.display_name  if rod  else "—"
	var bait_name := bait.display_name if bait else "—"
	equipped_label.text = "Rod: %s  Bait: %s" % [rod_name, bait_name]
