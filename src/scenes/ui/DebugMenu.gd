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
	var session := GameServer.get_session(multiplayer.get_unique_id())
	# 5 of each bait
	for item_id in ["worm", "lure", "magic_bait"]:
		if session: session.owned_items[item_id] = session.owned_items.get(item_id, 0) + 5
		GameManager.set_owned(item_id, GameManager.get_owned(item_id) + 5)
	# 1 of each hook
	for item_id in ["basic_hook", "golden_hook"]:
		if session: session.owned_items[item_id] = session.owned_items.get(item_id, 0) + 1
		GameManager.set_owned(item_id, GameManager.get_owned(item_id) + 1)
	# 1 of each rod only if not already owned
	for item_id in ["starter_rod", "angler_rod", "master_rod"]:
		if GameManager.get_owned(item_id) == 0:
			if session: session.owned_items[item_id] = 1
			GameManager.set_owned(item_id, 1)
	GameManager.owned_changed.emit()
