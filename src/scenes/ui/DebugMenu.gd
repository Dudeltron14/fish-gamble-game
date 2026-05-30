extends CanvasLayer

@onready var coins_label: Label = %CoinsLabel
@onready var zone_label: Label  = %ZoneLabel

func _ready() -> void:
	GameManager.coins_changed.connect(func(n): coins_label.text = "Coins: %d" % n)
	GameManager.zone_hint_changed.connect(func(_h): zone_label.text = "Zone: %s" % GameManager.current_zone)
	%GiveCoinsBtn.pressed.connect(_give_coins)
	%GiveGearBtn.pressed.connect(_give_gear)
	coins_label.text = "Coins: %d" % GameManager.current_coins

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		visible = not visible
		if visible:
			coins_label.text = "Coins: %d" % GameManager.current_coins
			zone_label.text = "Zone: %s" % (GameManager.current_zone if GameManager.current_zone else "—")

func _give_coins() -> void:
	GameManager.set_coins(9999)
	var session := GameServer.get_session(multiplayer.get_unique_id())
	if session:
		session.coins = 9999

func _give_gear() -> void:
	for item_id in ["worm", "lure", "magic_bait", "basic_hook", "golden_hook"]:
		var session := GameServer.get_session(multiplayer.get_unique_id())
		if session:
			session.owned_items[item_id] = session.owned_items.get(item_id, 0) + 10
		GameManager.set_owned(item_id, GameManager.get_owned(item_id) + 10)
	GameManager.owned_changed.emit()
