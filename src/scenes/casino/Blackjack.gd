extends CanvasLayer

signal completed

const RANKS := ["A","2","3","4","5","6","7","8","9","10","J","Q","K"]
const SUITS := ["♠","♥","♦","♣"]
const CARD_SIZE := Vector2(48, 70)
const CARD_DEAL_FLY_TIME := 0.32
const CARD_FLIP_HALF_TIME := 0.14
const CARD_DEAL_ARC_HEIGHT := 54.0
const COIN_BURST_SCENE := preload("res://src/scenes/vfx/CoinBurst.tscn")

enum State { IDLE, PLAYER_TURN }
var _state := State.IDLE
var _dealer_cards: Array = []
var _dealer_hole_hidden := false
var _player_value := 0

@onready var coins_label: Label     = %CoinsLabel
@onready var status_label: Label    = %StatusLabel
@onready var player_hand: HBoxContainer = %PlayerHand
@onready var player_value_label: Label = %PlayerValueLabel
@onready var deck_stack: TextureRect = %DeckStack
@onready var dealer_hand: HBoxContainer = %DealerHand
@onready var dealer_info_label: Label = %DealerInfoLabel
@onready var bet_spin: SpinBox      = %BetSpin
@onready var deal_btn: Button       = %DealBtn
@onready var hit_btn: Button        = %HitBtn
@onready var stand_btn: Button      = %StandBtn
@onready var double_btn: Button     = %DoubleBtn

func _ready() -> void:
	AudioManager.set_music_context("casino")
	NetAPI.bj_deal.connect(_on_deal)
	$Center/Panel/Margin/VBox/CloseBtn.pressed.connect(_on_leave_pressed)
	NetAPI.bj_hit.connect(_on_hit)
	NetAPI.bj_dealer_reveal.connect(_on_dealer_reveal)
	NetAPI.bj_dealer_card.connect(_on_dealer_card)
	NetAPI.bj_result.connect(_on_result)
	NetAPI.bj_error.connect(_on_error)
	if not GameManager.coins_changed.is_connected(_on_coins_changed):
		GameManager.coins_changed.connect(_on_coins_changed)
	# CloseBtn now connected to _on_leave_pressed in _ready() above
	deal_btn.pressed.connect(_on_deal_pressed)
	hit_btn.pressed.connect(func(): NetAPI.rpc_id(1, "c2s_bj_hit"))
	stand_btn.pressed.connect(func(): NetAPI.rpc_id(1, "c2s_bj_stand"))
	double_btn.pressed.connect(func(): NetAPI.rpc_id(1, "c2s_bj_double"))
	coins_label.text = "Coins: %d" % GameManager.current_coins
	_refresh_betting_controls()
	_set_actions(false)

# ── Input ─────────────────────────────────────────────────────────────────────

func _on_deal_pressed() -> void:
	var amount := int(bet_spin.value)
	if amount <= 0 or GameManager.current_coins <= 0 or amount > GameManager.current_coins:
		status_label.text = "You need coins to play."
		status_label.modulate = Color(1.0, 0.4, 0.4)
		_refresh_betting_controls()
		return
	_clear_hands()
	_set_actions(false)
	deal_btn.disabled = true
	status_label.text = "Dealing…"
	NetAPI.rpc_id(1, "c2s_bj_bet", amount)

# ── NetAPI callbacks ──────────────────────────────────────────────────────────

func _on_deal(player_cards: Array, dealer_visible: Dictionary, bet: int, balance: int) -> void:
	_state = State.PLAYER_TURN
	_clear_hands()
	_dealer_cards = [dealer_visible]
	_dealer_hole_hidden = true
	_update_dealer_info()
	# Deal cards with staggered back-to-face flips; keep the dealer hole card face down.
	var delay := 0.0
	_deal_card_animated(dealer_hand, _card_widget(dealer_visible), delay, true); delay += 0.24
	for c in player_cards:
		_deal_card_animated(player_hand, _card_widget(c), delay, true); delay += 0.24
	_deal_card_animated(dealer_hand, _hidden_widget(), delay, false)

	_player_value = _val(player_cards)
	_update_player_value()
	status_label.text = "Hit or Stand?"
	status_label.modulate = Color.WHITE
	coins_label.text = "Coins: %d  (bet: %d)" % [balance, bet]
	GameManager.set_coins(balance)
	_set_actions(true)
	double_btn.disabled = player_cards.size() != 2

func _on_hit(card: Dictionary, new_val: int) -> void:
	_deal_card_animated(player_hand, _card_widget(card), 0.0, true)
	_player_value = new_val
	_update_player_value()
	if new_val > 21:
		status_label.text = "Bust!"
		status_label.modulate = Color(1.0, 0.4, 0.4)
		_set_actions(false)
	else:
		status_label.text = "Hit or Stand?"
	double_btn.disabled = true

func _on_dealer_reveal(full_hand: Array, value: int) -> void:
	_clear_node(dealer_hand)
	_dealer_cards = full_hand.duplicate()
	_dealer_hole_hidden = false
	_update_dealer_info(value)
	# Flip the hole card with stagger
	var delay := 0.0
	for c in full_hand:
		_deal_card_animated(dealer_hand, _card_widget(c), delay, true); delay += 0.24
	status_label.text = "Dealer: %d — playing…" % value
	_set_actions(false)

func _on_dealer_card(card: Dictionary, value: int) -> void:
	_dealer_cards.append(card)
	_dealer_hole_hidden = false
	_update_dealer_info(value)
	_deal_card_animated(dealer_hand, _card_widget(card), 0.0, true)
	status_label.text = "Dealer: %d" % value

func _on_result(outcome: String, dh: Array, payout: int, new_balance: int) -> void:
	_dealer_cards = dh.duplicate()
	_dealer_hole_hidden = false
	_update_dealer_info(_val(dh))
	GameManager.set_coins(new_balance)
	coins_label.text = "Coins: %d" % new_balance
	var messages := {
		"win":  "You win! +%d coins" % payout,
		"bust": "Bust — you lose.",
		"lose": "Dealer wins.",
		"push": "Push — bet returned.",
	}
	status_label.text = messages.get(outcome, outcome)
	match outcome:
		"win":
			AudioManager.sfx("sfx_blackjack_win")
			AudioManager.sfx("sfx_coins")
			if payout > 0:
				_spawn_coin_bursts(payout)
		"bust", "lose": AudioManager.sfx("sfx_blackjack_lose")
		"push": AudioManager.sfx("sfx_blackjack_push")
	# Pulse the result label
	status_label.scale = Vector2(0.8, 0.8)
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(status_label, "scale", Vector2.ONE, 0.5)
	status_label.modulate = Color(0.3, 1.0, 0.4) if outcome == "win" \
		else Color(1.0, 0.4, 0.4) if outcome in ["bust", "lose"] \
		else Color.WHITE
	_state = State.IDLE
	_refresh_betting_controls()

func _on_error(msg: String) -> void:
	status_label.text = msg
	status_label.modulate = Color(1.0, 0.4, 0.4)
	_refresh_betting_controls()

# ── Card widgets ──────────────────────────────────────────────────────────────

const SUIT_NAMES := ["spades", "hearts", "diamonds", "clubs"]

func _card_texture(card: Dictionary) -> Texture2D:
	var suit: String = SUIT_NAMES[card["suit"]]
	var rank: int = int(card["rank"]) + 1  # server rank 0-12 → file rank 1-13
	var path := "res://assets/Playing Cards/card-%s-%d.png" % [suit, rank]
	var tex := load(path) as Texture2D
	if tex == null:
		push_warning("Blackjack: could not load card texture: " + path)
	return tex

func _card_widget(card: Dictionary) -> Control:
	var tex := _card_texture(card)
	if tex:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = CARD_SIZE
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return rect
	# Fallback to text if texture missing
	var is_red: bool = card["suit"] == 1 or card["suit"] == 2
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	var lbl := Label.new()
	lbl.text = RANKS[card["rank"]] + SUITS[card["suit"]]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.modulate = Color(0.9, 0.15, 0.15) if is_red else Color(0.9, 0.9, 0.9)
	panel.add_child(lbl)
	return panel

func _hidden_widget() -> Control:
	var back_tex := load("res://assets/Playing Cards/card-back1.png") as Texture2D
	if back_tex:
		var rect := TextureRect.new()
		rect.texture = back_tex
		rect.custom_minimum_size = CARD_SIZE
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return rect
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	var lbl := Label.new()
	lbl.text = "?"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(lbl)
	return panel

# ── Animation helpers ─────────────────────────────────────────────────────────

func _card_label(card: Dictionary) -> String:
	var rank: int = card["rank"]
	return RANKS[rank]

func _dealer_hand_text() -> String:
	var parts: Array[String] = []
	for card: Dictionary in _dealer_cards:
		parts.append(_card_label(card))
	if _dealer_hole_hidden:
		parts.append("hidden")
	return ", ".join(parts)

func _update_dealer_info(value: int = -1) -> void:
	if _dealer_cards.is_empty():
		dealer_info_label.text = ""
		return
	var shown_value: int = value if value >= 0 else _val(_dealer_cards)
	var title := "Dealer showing" if _dealer_hole_hidden else "Dealer hand"
	dealer_info_label.text = "%s: %s\n\nValue: %d" % [title, _dealer_hand_text(), shown_value]

func _deal_card_animated(hand: HBoxContainer, face_widget: Control, delay: float, reveal_face: bool = true) -> void:
	var card_widget := _hidden_widget() if reveal_face else face_widget
	card_widget.pivot_offset = CARD_SIZE * 0.5
	card_widget.modulate.a = 0.0
	hand.add_child(card_widget)
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(func(): _start_card_deal(hand, card_widget, face_widget, reveal_face))

func _start_card_deal(hand: HBoxContainer, card_widget: Control, face_widget: Control, reveal_face: bool) -> void:
	await get_tree().process_frame
	if not is_instance_valid(card_widget):
		return
	AudioManager.sfx("sfx_card_deal")
	var flying_card := _hidden_widget()
	add_child(flying_card)
	flying_card.size = CARD_SIZE
	flying_card.pivot_offset = CARD_SIZE * 0.5
	var start_position := _card_top_left_from_center(_control_center(deck_stack))
	var target_position := _card_top_left_from_center(_control_center(card_widget))
	var arc_dir := -1.0 if target_position.y < start_position.y else 1.0
	var control_position := (start_position + target_position) * 0.5 + Vector2(0.0, CARD_DEAL_ARC_HEIGHT * arc_dir)
	flying_card.global_position = start_position
	flying_card.rotation = deg_to_rad(-8.0 * arc_dir)
	var tween := create_tween().set_parallel(true)
	var deal_curve := func(progress: float) -> void:
		if is_instance_valid(flying_card):
			flying_card.global_position = _quadratic_bezier(start_position, control_position, target_position, progress)
	tween.tween_method(deal_curve, 0.0, 1.0, CARD_DEAL_FLY_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(flying_card, "rotation", 0.0, CARD_DEAL_FLY_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.finished.connect(func():
		if is_instance_valid(flying_card):
			flying_card.queue_free()
		if not is_instance_valid(card_widget):
			return
		card_widget.modulate.a = 1.0
		card_widget.scale = Vector2.ONE
		_flip_card_in_place(hand, card_widget, face_widget, reveal_face)
	)

func _control_center(control: Control) -> Vector2:
	return control.global_position + control.size * 0.5

func _card_top_left_from_center(center: Vector2) -> Vector2:
	return center - CARD_SIZE * 0.5

func _quadratic_bezier(start: Vector2, control: Vector2, end: Vector2, progress: float) -> Vector2:
	var inverse := 1.0 - progress
	return inverse * inverse * start + 2.0 * inverse * progress * control + progress * progress * end

func _flip_card_in_place(hand: HBoxContainer, card_widget: Control, face_widget: Control, reveal_face: bool) -> void:
	if not reveal_face:
		return
	card_widget.pivot_offset = CARD_SIZE * 0.5
	var tween := create_tween()
	tween.tween_property(card_widget, "scale:x", 0.0, CARD_FLIP_HALF_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	if card_widget is TextureRect and face_widget is TextureRect:
		tween.tween_callback(func():
			if is_instance_valid(card_widget):
				AudioManager.sfx("sfx_card_flip")
				(card_widget as TextureRect).texture = (face_widget as TextureRect).texture
		)
		tween.tween_property(card_widget, "scale:x", 1.0, CARD_FLIP_HALF_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	else:
		tween.tween_callback(func():
			if not is_instance_valid(card_widget):
				return
			AudioManager.sfx("sfx_card_flip")
			var index := card_widget.get_index()
			card_widget.queue_free()
			hand.add_child(face_widget)
			hand.move_child(face_widget, index)
			face_widget.pivot_offset = CARD_SIZE * 0.5
			face_widget.scale = Vector2(0.0, 1.0)
			var fallback_tween := create_tween()
			fallback_tween.tween_property(face_widget, "scale:x", 1.0, CARD_FLIP_HALF_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _val(hand: Array) -> int:
	var total := 0; var aces := 0
	for card in hand:
		var r: int = card["rank"]
		if r == 0:   aces += 1; total += 11
		elif r >= 9: total += 10
		else:        total += r + 1
	while total > 21 and aces > 0:
		total -= 10; aces -= 1
	return total

func _set_actions(on: bool) -> void:
	hit_btn.disabled = not on
	stand_btn.disabled = not on
	double_btn.disabled = not on
	if not on:
		_refresh_betting_controls()

func _on_coins_changed(new_amount: int) -> void:
	coins_label.text = "Coins: %d" % new_amount if _state == State.IDLE else coins_label.text
	_refresh_betting_controls()

func _refresh_betting_controls() -> void:
	var balance: int = maxi(0, GameManager.current_coins)
	bet_spin.min_value = 1.0 if balance > 0 else 0.0
	bet_spin.max_value = maxi(1, balance)
	if balance <= 0:
		bet_spin.value = 0.0
		deal_btn.disabled = true
		if _state == State.IDLE:
			status_label.text = "You need coins to play."
	else:
		if int(bet_spin.value) <= 0 or int(bet_spin.value) > balance:
			bet_spin.value = mini(10, balance)
		deal_btn.disabled = _state != State.IDLE

func _clear_hands() -> void:
	_clear_node(player_hand)
	_clear_node(dealer_hand)
	_dealer_cards.clear()
	_dealer_hole_hidden = false
	_player_value = 0
	player_value_label.text = ""
	dealer_info_label.text = ""

func _update_player_value() -> void:
	player_value_label.text = "Your hand: %d" % _player_value

func _spawn_coin_bursts(payout: int) -> void:
	var count := 1
	if payout >= 500:
		count = 14
	elif payout >= 100:
		count = 7
	elif payout >= 50:
		count = 3

	var center := status_label.global_position + Vector2(status_label.size.x * 0.5, -18.0)
	var spread := Vector2(34.0, 12.0)
	if payout >= 100:
		spread = Vector2(140.0, 42.0)
	elif payout >= 50:
		spread = Vector2(78.0, 24.0)

	for i in count:
		var burst := COIN_BURST_SCENE.instantiate() as Node2D
		add_child(burst)
		var offset := Vector2(randf_range(-spread.x, spread.x), randf_range(-spread.y, spread.y))
		burst.global_position = center + offset
		if i > 0:
			burst.modulate.a = 0.0
			var tween := create_tween()
			tween.tween_interval(float(i) * 0.045)
			tween.tween_property(burst, "modulate:a", 1.0, 0.01)

func _clear_node(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_leave_pressed()

func _on_leave_pressed() -> void:
	if _state == State.IDLE:
		_close()
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Leave the Table?"
	dialog.dialog_text = "You have an active hand.\nLeaving now forfeits your bet — you will not be refunded."
	dialog.ok_button_text = "Leave and Forfeit"
	dialog.cancel_button_text = "Stay"
	dialog.confirmed.connect(_forfeit_and_close)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _forfeit_and_close() -> void:
	NetAPI.rpc_id(1, "c2s_bj_forfeit")
	_close()

func _close() -> void:
	AudioManager.set_music_context("world")
	completed.emit()
	queue_free()
