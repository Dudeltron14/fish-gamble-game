extends Node

const TABLE_ID := "blackjack_harbor_1"
const TABLE_ZONE := "CasinoZone"
const SEAT_COUNT := 4
const SHUFFLE_CUT_CARD := 52 * 3
const BETTING_WINDOW_SECONDS := 8.0
const TURN_TIMEOUT_SECONDS := 20.0
const RESULT_SECONDS := 3.0

enum Phase { BETTING, PLAYER_TURNS, DEALER_TURN, RESULTS }

var _shoe: Array = []
var _shoe_seed := ""
var _shoe_nonce := ""
var _shoe_commitment := ""
var _shoe_dealt: Array = []
var _shoe_audit: Array = []
var _next_hand_id := 1
var _round_id := 0
var _phase := Phase.BETTING
var _hands: Dictionary = {}
var _dealer_hand: Array = []
var _dealer_hole_hidden := true
var _round_timer: Timer
var _turn_timer: Timer
var _result_timer: Timer

func _ready() -> void:
	_tables().register_table(TABLE_ID, "blackjack", TABLE_ZONE, SEAT_COUNT)
	_round_timer = _timer(BETTING_WINDOW_SECONDS, _start_round)
	_turn_timer = _timer(TURN_TIMEOUT_SECONDS, _on_turn_timeout)
	_result_timer = _timer(RESULT_SECONDS, _reset_round)

func _timer(wait_time: float, callback: Callable) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = wait_time
	timer.timeout.connect(callback)
	add_child(timer)
	return timer

func handle_table_enter(peer_id: int) -> void:
	var session: PlayerSession = GameServer.get_authenticated_session(peer_id)
	if session == null or session.current_zone != TABLE_ZONE:
		_err(peer_id, "Not at a table.")
		return
	if _shoe.is_empty():
		_start_new_shoe()
	_tables().watch(TABLE_ID, peer_id)
	var seat: int = _tables().join(TABLE_ID, peer_id)
	if seat < 0:
		_err(peer_id, "Table is full. You are spectating.")
	_broadcast_table()
	_rpc_to(peer_id, "notify_bj_shoe_commitment", [_shoe_commitment, _shoe.size()])
	_rpc_to(peer_id, "notify_bj_shoe_count", [_shoe.size()])

func handle_table_leave(peer_id: int) -> void:
	if _hands.has(peer_id):
		_forfeit_hand(peer_id)
	_tables().leave(TABLE_ID, peer_id)
	_tables().unwatch(TABLE_ID, peer_id)
	_broadcast_table()

func handle_player_left(peer_id: int) -> void:
	if not _hands.has(peer_id):
		return
	if _phase == Phase.BETTING:
		_forfeit_hand(peer_id)
		return
	var hand: Dictionary = _hands[peer_id]
	if str(hand["state"]) == "turn":
		hand["state"] = "stand"
		_hands[peer_id] = hand
		_tables().leave(TABLE_ID, peer_id)
		_advance_turn()
		return
	if str(hand["state"]) == "ready":
		hand["state"] = "stand"
		_hands[peer_id] = hand
	_tables().leave(TABLE_ID, peer_id)
	_broadcast_table()

func handle_shoe_count(peer_id: int) -> void:
	if _shoe.is_empty():
		_start_new_shoe()
	_rpc_to(peer_id, "notify_bj_shoe_commitment", [_shoe_commitment, _shoe.size()])
	_rpc_to(peer_id, "notify_bj_shoe_count", [_shoe.size()])

func handle_bet(peer_id: int, amount: int) -> void:
	var session: PlayerSession = GameServer.get_authenticated_session(peer_id)
	if session == null or session.current_zone != TABLE_ZONE:
		_err(peer_id, "Not at a table.")
		return
	if _phase != Phase.BETTING:
		_err(peer_id, "This round is already in progress.")
		return
	if _hands.has(peer_id):
		_err(peer_id, "Bet already placed for this round.")
		return
	if not _tables().is_seated(TABLE_ID, peer_id):
		if _tables().join(TABLE_ID, peer_id) < 0:
			_err(peer_id, "Table is full. You are spectating.")
			return
	if amount <= 0 or amount > session.coins:
		_err(peer_id, "Not enough coins.")
		return
	session.coins -= amount
	_save_coins(session)
	var progression: Node = GameServer.get_node_or_null("ProgressionServer")
	if progression:
		progression.record_hand_played(session)
	var hand_id: int = _next_hand_id
	_next_hand_id += 1
	_hands[peer_id] = {"peer_id": peer_id, "username": session.username, "hand_id": hand_id, "bet": amount, "cards": [], "state": "ready", "doubled": false, "balance": session.coins}
	if _round_timer.is_stopped():
		_round_timer.start()
	_broadcast_table()

func handle_hit(peer_id: int) -> void:
	if not _is_active_turn(peer_id):
		_err(peer_id, "Wait for your turn.")
		return
	var hand: Dictionary = _hands[peer_id]
	var cards: Array = hand["cards"]
	var card: Dictionary = _draw_card(str(hand["username"]), "hit", int(hand["hand_id"]), peer_id)
	cards.append(card)
	hand["cards"] = cards
	var value: int = _val(cards)
	if value > 21:
		hand["state"] = "bust"
	elif value == 21:
		hand["state"] = "stand"
	_hands[peer_id] = hand
	_broadcast_shoe_count()
	_rpc_to(peer_id, "notify_bj_hit", [card, value, _shoe.size()])
	if str(hand["state"]) == "turn":
		_broadcast_table()
	else:
		_advance_turn()

func handle_stand(peer_id: int) -> void:
	if not _is_active_turn(peer_id):
		_err(peer_id, "Wait for your turn.")
		return
	var hand: Dictionary = _hands[peer_id]
	hand["state"] = "stand"
	_hands[peer_id] = hand
	_record_audit(str(hand["username"]), "stand", int(hand["hand_id"]), peer_id)
	_advance_turn()

func handle_double(peer_id: int) -> void:
	if not _is_active_turn(peer_id):
		_err(peer_id, "Wait for your turn.")
		return
	var session: PlayerSession = GameServer.get_authenticated_session(peer_id)
	var hand: Dictionary = _hands[peer_id]
	var cards: Array = hand["cards"]
	var bet: int = int(hand["bet"])
	if session == null or cards.size() != 2 or session.coins < bet:
		_err(peer_id, "Not enough coins to double down.")
		return
	session.coins -= bet
	_save_coins(session)
	hand["bet"] = bet * 2
	hand["balance"] = session.coins
	hand["doubled"] = true
	var card: Dictionary = _draw_card(str(hand["username"]), "double", int(hand["hand_id"]), peer_id)
	cards.append(card)
	hand["cards"] = cards
	hand["state"] = "bust" if _val(cards) > 21 else "stand"
	_hands[peer_id] = hand
	_broadcast_shoe_count()
	_rpc_to(peer_id, "notify_bj_hit", [card, _val(cards), _shoe.size()])
	_advance_turn()

func handle_forfeit(peer_id: int) -> void:
	if _hands.has(peer_id):
		_forfeit_hand(peer_id)
	_tables().leave(TABLE_ID, peer_id)
	_broadcast_table()

func _start_round() -> void:
	if _phase != Phase.BETTING or _hands.is_empty():
		return
	if _shoe.size() <= SHUFFLE_CUT_CARD:
		_start_new_shoe()
		_table_rpc("notify_bj_shuffled", [_shoe.size()])
	_round_id += 1
	_phase = Phase.PLAYER_TURNS
	_dealer_hole_hidden = true
	_dealer_hand = [_draw_card("Dealer", "deal", 0), _draw_card("Dealer", "deal", 0)]
	var turn_order: Array[int] = []
	for peer_id: int in _tables().occupied_peers(TABLE_ID):
		if not _hands.has(peer_id):
			continue
		var hand: Dictionary = _hands[peer_id]
		var cards: Array = [_draw_card(str(hand["username"]), "deal", int(hand["hand_id"]), peer_id), _draw_card(str(hand["username"]), "deal", int(hand["hand_id"]), peer_id)]
		hand["cards"] = cards
		if _val(cards) == 21:
			hand["state"] = "blackjack"
		_hands[peer_id] = hand
		turn_order.append(peer_id)
		var session: PlayerSession = GameServer.get_authenticated_session(peer_id)
		if session:
			_rpc_to(peer_id, "notify_bj_deal", [cards, _dealer_hand[0], int(hand["bet"]), session.coins, _shoe.size()])
	_broadcast_shoe_count()
	if _dealer_peeks_blackjack(_dealer_hand):
		_run_dealer()
		return
	_tables().set_turn_order(TABLE_ID, turn_order)
	_advance_turn()

func _advance_turn() -> void:
	_turn_timer.stop()
	var peer_id: int = _tables().next_turn_peer(TABLE_ID)
	while peer_id != 0:
		var hand: Dictionary = _hands.get(peer_id, {})
		if not hand.is_empty() and str(hand["state"]) == "ready":
			hand["state"] = "turn"
			_hands[peer_id] = hand
			_turn_timer.start()
			_broadcast_table()
			return
		peer_id = _tables().next_turn_peer(TABLE_ID)
	_run_dealer()

func _on_turn_timeout() -> void:
	if _phase != Phase.PLAYER_TURNS:
		return
	var peer_id: int = _tables().current_turn_peer(TABLE_ID)
	if peer_id == 0:
		return
	if not _hands.has(peer_id):
		_advance_turn()
		return
	var hand: Dictionary = _hands[peer_id]
	if str(hand["state"]) == "turn":
		hand["state"] = "stand"
		_hands[peer_id] = hand
		_record_audit(str(hand["username"]), "timeout_stand", int(hand["hand_id"]), peer_id)
	_advance_turn()

func _run_dealer() -> void:
	_phase = Phase.DEALER_TURN
	_dealer_hole_hidden = false
	_tables().set_active_seat(TABLE_ID, -1)
	for peer_id: int in _tables().recipients(TABLE_ID):
		_rpc_to(peer_id, "notify_bj_dealer_reveal", [_dealer_hand, _val(_dealer_hand), _shoe.size()])
	while _val(_dealer_hand) < 17:
		var card: Dictionary = _draw_card("Dealer", "draw", 0)
		_dealer_hand.append(card)
		_broadcast_shoe_count()
		for peer_id: int in _tables().recipients(TABLE_ID):
			_rpc_to(peer_id, "notify_bj_dealer_card", [card, _val(_dealer_hand), _shoe.size()])
	_resolve_round()

func _resolve_round() -> void:
	_phase = Phase.RESULTS
	var dealer_value: int = _val(_dealer_hand)
	for peer_id: int in _hands.keys():
		var hand: Dictionary = _hands[peer_id]
		var outcome := "lose"
		var payout := 0
		var cards: Array = hand["cards"]
		var player_value: int = _val(cards)
		if str(hand["state"]) == "forfeit" or player_value > 21:
			outcome = "bust" if player_value > 21 else "lose"
		elif dealer_value > 21 or player_value > dealer_value:
			outcome = "win"
			payout = int(int(hand["bet"]) * 2.5) if player_value == 21 and cards.size() == 2 else int(hand["bet"]) * 2
		elif player_value == dealer_value:
			outcome = "push"
			payout = int(hand["bet"])
		hand["state"] = outcome
		hand["payout"] = payout
		_hands[peer_id] = hand
		_record_audit(str(hand["username"]), outcome, int(hand["hand_id"]), peer_id)
		_settle_hand(peer_id, hand, outcome, payout)
	_broadcast_table()
	_result_timer.start()

func _settle_hand(peer_id: int, hand: Dictionary, outcome: String, payout: int) -> void:
	var balance: int = int(hand["balance"]) + payout
	var session: PlayerSession = GameServer.get_authenticated_session(peer_id)
	if session:
		session.coins = balance
		var progression: Node = GameServer.get_node_or_null("ProgressionServer")
		if progression:
			progression.record_blackjack_result(session, maxi(0, payout - int(hand["bet"])), int(hand["bet"]) if payout == 0 else 0, int(hand["bet"]), bool(hand["doubled"]), outcome)
		_save_coins(session)
		_rpc_to(peer_id, "notify_bj_result", [outcome, _dealer_hand, payout, balance])
	else:
		_save_balance(str(hand["username"]), balance)
	GameServer.broadcast_leaderboard()

func _forfeit_hand(peer_id: int) -> void:
	var hand: Dictionary = _hands.get(peer_id, {})
	if hand.is_empty():
		return
	if _phase == Phase.BETTING:
		_hands.erase(peer_id)
		return
	hand["state"] = "forfeit"
	_hands[peer_id] = hand
	_record_audit(str(hand["username"]), "forfeit", int(hand["hand_id"]), peer_id)
	if _phase == Phase.PLAYER_TURNS and _tables().current_turn_peer(TABLE_ID) == peer_id:
		_advance_turn()

func _reset_round() -> void:
	_hands.clear()
	_dealer_hand.clear()
	_dealer_hole_hidden = true
	_tables().clear_turns(TABLE_ID)
	_phase = Phase.BETTING
	_tables().set_active_seat(TABLE_ID, -1)
	_broadcast_table()

func _broadcast_table() -> void:
	var phase_name: String = ["betting", "player_turns", "dealer_turn", "results"][_phase]
	_tables().set_phase(TABLE_ID, phase_name)
	for peer_id: int in _tables().occupied_peers(TABLE_ID):
		var hand: Dictionary = _hands.get(peer_id, {})
		var public_state: Dictionary = {}
		if not hand.is_empty():
			public_state = {"bet": int(hand["bet"]), "cards": Array(hand["cards"]).duplicate(true), "state": str(hand["state"]), "value": _val(Array(hand["cards"])), "payout": int(hand.get("payout", 0))}
		_tables().set_seat_public(TABLE_ID, peer_id, public_state)
	var state: Dictionary = _tables().snapshot(TABLE_ID)
	state["round_id"] = _round_id
	state["cards_left"] = _shoe.size()
	state["next_action_seconds"] = _next_action_seconds()
	state["dealer"] = {"cards": _dealer_hand.slice(0, 1) if _dealer_hole_hidden and not _dealer_hand.is_empty() else _dealer_hand.duplicate(true), "hole_hidden": _dealer_hole_hidden, "value": _val(_dealer_hand) if not _dealer_hole_hidden else _val(_dealer_hand.slice(0, 1))}
	_table_rpc("notify_casino_table_state", [TABLE_ID, state])

func _next_action_seconds() -> float:
	if _phase == Phase.BETTING:
		return _round_timer.time_left
	if _phase == Phase.PLAYER_TURNS:
		return _turn_timer.time_left
	return 0.0

func _is_active_turn(peer_id: int) -> bool:
	if _phase != Phase.PLAYER_TURNS:
		return false
	return _tables().current_turn_peer(TABLE_ID) == peer_id and _hands.has(peer_id) and str(_hands[peer_id]["state"]) == "turn"

func _tables():
	return GameServer.get_node("TableManager")

func _start_new_shoe() -> void:
	if not _shoe_commitment.is_empty():
		_reveal_current_shoe()
	_shuffle_shoe()
	_persist_shoe(false)
	_table_rpc("notify_bj_shoe_commitment", [_shoe_commitment, _shoe.size()])

func _shuffle_shoe(seed_value: String = "", nonce: String = "") -> void:
	_shoe_seed = seed_value if not seed_value.is_empty() else BlackjackFairness.secure_token()
	_shoe_nonce = nonce if not nonce.is_empty() else BlackjackFairness.secure_token(16)
	_shoe_commitment = BlackjackFairness.commitment(_shoe_seed, _shoe_nonce)
	_shoe = BlackjackFairness.make_shoe(_shoe_seed, _shoe_nonce)
	_shoe_dealt.clear()
	_shoe_audit.clear()
	_next_hand_id = 1

func _draw_card(actor: String, action: String, hand_id: int, peer_id: int = 0) -> Dictionary:
	var card: Dictionary = _shoe.pop_back()
	_shoe_dealt.append(card)
	_shoe_audit.append({"actor": actor, "action": action, "card": card, "round_id": _round_id, "hand_id": hand_id, "seat": _tables().seat_index(TABLE_ID, peer_id)})
	_persist_shoe(false)
	return card

func _record_audit(actor: String, action: String, hand_id: int, peer_id: int = 0) -> void:
	_shoe_audit.append({"actor": actor, "action": action, "round_id": _round_id, "hand_id": hand_id, "seat": _tables().seat_index(TABLE_ID, peer_id)})
	_persist_shoe(false)

func _reveal_current_shoe() -> void:
	_persist_shoe(true)
	_table_rpc("notify_bj_shoe_revealed", [_shoe_commitment, _shoe_seed, _shoe_nonce, _shoe_dealt, _shoe_audit])

func _persist_shoe(revealed: bool) -> void:
	var auth: Node = GameServer.get_node_or_null("AuthServer")
	if auth == null or auth._db == null:
		return
	if revealed:
		auth._db.query_with_bindings("UPDATE blackjack_shoes SET dealt_cards = ?, audit_log = ?, revealed_at = ? WHERE commitment = ?", [JSON.stringify(_shoe_dealt), JSON.stringify(_shoe_audit), int(Time.get_unix_time_from_system()), _shoe_commitment])
		return
	auth._db.query_with_bindings("INSERT INTO blackjack_shoes (commitment, seed, nonce, dealt_cards, audit_log, created_at) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(commitment) DO UPDATE SET dealt_cards = excluded.dealt_cards, audit_log = excluded.audit_log", [_shoe_commitment, _shoe_seed, _shoe_nonce, JSON.stringify(_shoe_dealt), JSON.stringify(_shoe_audit), int(Time.get_unix_time_from_system())])

func _broadcast_shoe_count() -> void:
	_table_rpc("notify_bj_shoe_count", [_shoe.size()])

func _table_rpc(method: String, arguments: Array) -> void:
	for peer_id: int in _tables().recipients(TABLE_ID):
		_rpc_to(peer_id, method, arguments)

func _val(hand: Array) -> int:
	var total := 0
	var aces := 0
	for card: Dictionary in hand:
		var rank: int = int(card["rank"])
		if rank == 0:
			aces += 1
			total += 11
		elif rank >= 9:
			total += 10
		else:
			total += rank + 1
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total

func _dealer_peeks_blackjack(hand: Array) -> bool:
	return hand.size() == 2 and int(hand[0]["rank"]) == 0 and _val(hand) == 21

func _err(peer_id: int, message: String) -> void:
	_rpc_to(peer_id, "notify_bj_error", [message])

func _rpc_to(peer_id: int, method: String, arguments: Array) -> void:
	if peer_id != 1 and not multiplayer.get_peers().has(peer_id):
		return
	var call_args: Array = [peer_id, method]
	call_args.append_array(arguments)
	NetAPI.rpc_id.callv(call_args)

func _save_coins(session: PlayerSession) -> void:
	_save_balance(session.username, session.coins)

func _save_balance(username: String, coins: int) -> void:
	var auth: Node = GameServer.get_node_or_null("AuthServer")
	if auth and auth._db:
		auth._db.query_with_bindings("UPDATE players SET coins = ? WHERE username = ?", [coins, username])
