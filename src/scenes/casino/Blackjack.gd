extends CanvasLayer

signal completed

const RANKS := ["A","2","3","4","5","6","7","8","9","10","J","Q","K"]
const SUITS := ["♠","♥","♦","♣"]

enum State { IDLE, PLAYER_TURN }
var _state := State.IDLE

@onready var coins_label: Label     = %CoinsLabel
@onready var status_label: Label    = %StatusLabel
@onready var player_hand: HBoxContainer = %PlayerHand
@onready var dealer_hand: HBoxContainer = %DealerHand
@onready var bet_spin: SpinBox      = %BetSpin
@onready var deal_btn: Button       = %DealBtn
@onready var hit_btn: Button        = %HitBtn
@onready var stand_btn: Button      = %StandBtn
@onready var double_btn: Button     = %DoubleBtn

func _ready() -> void:
	NetAPI.bj_deal.connect(_on_deal)
	NetAPI.bj_hit.connect(_on_hit)
	NetAPI.bj_dealer_reveal.connect(_on_dealer_reveal)
	NetAPI.bj_dealer_card.connect(_on_dealer_card)
	NetAPI.bj_result.connect(_on_result)
	NetAPI.bj_error.connect(_on_error)
	$Center/Panel/Margin/VBox/CloseBtn.pressed.connect(_close)
	deal_btn.pressed.connect(_on_deal_pressed)
	hit_btn.pressed.connect(func(): NetAPI.rpc("c2s_bj_hit"))
	stand_btn.pressed.connect(func(): NetAPI.rpc("c2s_bj_stand"))
	double_btn.pressed.connect(func(): NetAPI.rpc("c2s_bj_double"))
	bet_spin.max_value = GameManager.current_coins
	bet_spin.value = mini(10, GameManager.current_coins)
	coins_label.text = "Coins: %d" % GameManager.current_coins
	_set_actions(false)

# ── Input ─────────────────────────────────────────────────────────────────────

func _on_deal_pressed() -> void:
	var amount := int(bet_spin.value)
	if amount <= 0: return
	_clear_hands()
	_set_actions(false)
	deal_btn.disabled = true
	status_label.text = "Dealing…"
	NetAPI.rpc("c2s_bj_bet", amount)

# ── NetAPI callbacks ──────────────────────────────────────────────────────────

func _on_deal(player_cards: Array, dealer_visible: Dictionary, bet: int, balance: int) -> void:
	_state = State.PLAYER_TURN
	_clear_hands()
	for c in player_cards:
		player_hand.add_child(_card_widget(c))
	dealer_hand.add_child(_card_widget(dealer_visible))
	dealer_hand.add_child(_hidden_widget())
	var pv := _val(player_cards)
	status_label.text = "Your hand: %d — Hit or Stand?" % pv
	status_label.modulate = Color.WHITE
	coins_label.text = "Coins: %d  (bet: %d)" % [balance, bet]
	bet_spin.max_value = balance
	_set_actions(true)
	double_btn.disabled = player_cards.size() != 2

func _on_hit(card: Dictionary, new_val: int) -> void:
	player_hand.add_child(_card_widget(card))
	if new_val > 21:
		status_label.text = "Bust! (%d)" % new_val
		status_label.modulate = Color(1.0, 0.4, 0.4)
		_set_actions(false)
	else:
		status_label.text = "Your hand: %d" % new_val
	double_btn.disabled = true

func _on_dealer_reveal(full_hand: Array, value: int) -> void:
	_clear_node(dealer_hand)
	for c in full_hand:
		dealer_hand.add_child(_card_widget(c))
	status_label.text = "Dealer: %d — playing…" % value
	_set_actions(false)

func _on_dealer_card(card: Dictionary, value: int) -> void:
	dealer_hand.add_child(_card_widget(card))
	status_label.text = "Dealer: %d" % value

func _on_result(outcome: String, _dh: Array, payout: int, new_balance: int) -> void:
	GameManager.current_coins = new_balance
	coins_label.text = "Coins: %d" % new_balance
	bet_spin.max_value = new_balance
	var messages := {
		"win":  "You win! +%d coins" % payout,
		"bust": "Bust — you lose.",
		"lose": "Dealer wins.",
		"push": "Push — bet returned.",
	}
	status_label.text = messages.get(outcome, outcome)
	status_label.modulate = Color(0.3, 1.0, 0.4) if outcome == "win" \
		else Color(1.0, 0.4, 0.4) if outcome in ["bust", "lose"] \
		else Color.WHITE
	deal_btn.disabled = false
	_state = State.IDLE

func _on_error(msg: String) -> void:
	status_label.text = msg
	status_label.modulate = Color(1.0, 0.4, 0.4)
	deal_btn.disabled = false

# ── Card widgets ──────────────────────────────────────────────────────────────

func _card_widget(card: Dictionary) -> Control:
	var is_red := card["suit"] == 1 or card["suit"] == 2
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(48, 70)
	var lbl := Label.new()
	lbl.text = RANKS[card["rank"]] + SUITS[card["suit"]]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.modulate = Color(0.9, 0.15, 0.15) if is_red else Color(0.9, 0.9, 0.9)
	panel.add_child(lbl)
	return panel

func _hidden_widget() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(48, 70)
	var lbl := Label.new()
	lbl.text = "?"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(lbl)
	return panel

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

func _clear_hands() -> void:
	_clear_node(player_hand)
	_clear_node(dealer_hand)

func _clear_node(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _state == State.IDLE:
		_close()

func _close() -> void:
	completed.emit()
	queue_free()
