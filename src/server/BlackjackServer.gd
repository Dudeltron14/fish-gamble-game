extends Node

enum State { PLAYER_TURN, DEALER_TURN }
const SHUFFLE_CUT_CARD := 52 * 3

var _shoe: Array = []
var _shoe_seed := ""
var _shoe_nonce := ""
var _shoe_commitment := ""
var _shoe_dealt: Array = []
var _shoe_audit: Array = []

func handle_shoe_count(peer_id: int) -> void:
	if _shoe.is_empty():
		_start_new_shoe()
	NetAPI.rpc_id(peer_id, "notify_bj_shoe_commitment", _shoe_commitment, _shoe.size())
	NetAPI.rpc_id(peer_id, "notify_bj_shoe_count", _shoe.size())

func handle_bet(peer_id: int, amount: int) -> void:
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null or session.current_zone != "CasinoZone":
		_err(peer_id, "Not at a table."); return
	if session.has_meta("bj_state"):
		_err(peer_id, "Game already in progress."); return

	if session.coins <= 0:
		_err(peer_id, "You need coins to play."); return
	if amount <= 0:
		_err(peer_id, "Enter a valid bet."); return
	if amount > session.coins:
		_err(peer_id, "Not enough coins."); return

	session.coins -= amount
	session.set_meta("bj_bet", amount)

	if _shoe.size() <= SHUFFLE_CUT_CARD:
		_start_new_shoe()
		NetAPI.rpc_id(peer_id, "notify_bj_shuffled", _shoe.size())
	var player_name := session.username if not session.username.is_empty() else "Player"
	var ph: Array = [_draw_card(player_name, "deal"), _draw_card(player_name, "deal")]
	var dh: Array = [_draw_card("Dealer", "deal"), _draw_card("Dealer", "deal")]
	_broadcast_shoe_count()
	session.set_meta("bj_state", State.PLAYER_TURN)
	session.set_meta("bj_ph",    ph)
	session.set_meta("bj_dh",    dh)

	NetAPI.rpc_id(peer_id, "notify_bj_deal", ph, dh[0], amount, session.coins, _shoe.size())

	if _val(ph) == 21:
		_resolve_natural_blackjack(peer_id, session)

func handle_hit(peer_id: int) -> void:
	var session := GameServer.get_authenticated_session(peer_id)
	if not _in_player_turn(session): return
	var ph: Array   = session.get_meta("bj_ph")
	var card := _draw_card(session.username, "hit")
	ph.append(card)
	_broadcast_shoe_count()
	session.set_meta("bj_ph",   ph)
	NetAPI.rpc_id(peer_id, "notify_bj_hit", card, _val(ph), _shoe.size())
	if _val(ph) > 21:
		_resolve(peer_id, session)
	elif _val(ph) == 21:
		_run_dealer(peer_id, session)

func handle_stand(peer_id: int) -> void:
	var session := GameServer.get_authenticated_session(peer_id)
	if not _in_player_turn(session): return
	_run_dealer(peer_id, session)

func handle_double(peer_id: int) -> void:
	var session := GameServer.get_authenticated_session(peer_id)
	if not _in_player_turn(session): return
	var ph: Array = session.get_meta("bj_ph")
	if ph.size() != 2: return
	var bet: int = session.get_meta("bj_bet")
	if session.coins < bet:
		_err(peer_id, "Not enough coins to double down."); return
	var extra := bet
	session.coins -= extra
	session.set_meta("bj_bet", bet + extra)
	var card := _draw_card(session.username, "double")
	ph.append(card)
	_broadcast_shoe_count()
	session.set_meta("bj_ph",   ph)
	NetAPI.rpc_id(peer_id, "notify_bj_hit", card, _val(ph), _shoe.size())
	if _val(ph) > 21:
		_resolve(peer_id, session)
	else:
		_run_dealer(peer_id, session)

func handle_forfeit(peer_id: int) -> void:
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null: return
	for key in ["bj_state", "bj_ph", "bj_dh", "bj_bet"]:
		if session.has_meta(key):
			session.remove_meta(key)
	_save_coins(session)  # persist — bet was already deducted, no refund

# ── Internal ──────────────────────────────────────────────────────────────────

func _run_dealer(peer_id: int, session: PlayerSession) -> void:
	session.set_meta("bj_state", State.DEALER_TURN)
	var dh: Array   = session.get_meta("bj_dh")

	NetAPI.rpc_id(peer_id, "notify_bj_dealer_reveal", dh, _val(dh), _shoe.size())

	while _val(dh) < 17:
		var card := _draw_card("Dealer", "draw")
		dh.append(card)
		_broadcast_shoe_count()
		NetAPI.rpc_id(peer_id, "notify_bj_dealer_card", card, _val(dh), _shoe.size())

	session.set_meta("bj_dh",   dh)
	_resolve(peer_id, session)

func _resolve_natural_blackjack(peer_id: int, session: PlayerSession) -> void:
	var dh: Array = session.get_meta("bj_dh")
	NetAPI.rpc_id(peer_id, "notify_bj_dealer_reveal", dh, _val(dh), _shoe.size())
	_resolve(peer_id, session)

func _resolve(peer_id: int, session: PlayerSession) -> void:
	var ph: Array = session.get_meta("bj_ph")
	var dh: Array = session.get_meta("bj_dh")
	var bet: int  = session.get_meta("bj_bet")
	var pv := _val(ph)
	var dv := _val(dh)

	var outcome := "lose"
	var payout  := 0
	if pv > 21:
		outcome = "bust"
	elif dv > 21 or pv > dv:
		outcome = "win"
		payout = bet * 2
		if pv == 21 and ph.size() == 2:
			payout = int(bet * 2.5)  # blackjack 3:2
	elif pv == dv:
		outcome = "push"
		payout = bet

	session.coins += payout
	_save_coins(session)

	for key in ["bj_state", "bj_ph", "bj_dh", "bj_bet"]:
		if session.has_meta(key):
			session.remove_meta(key)

	NetAPI.rpc_id(peer_id, "notify_bj_result", outcome, dh, payout, session.coins)

func _start_new_shoe() -> void:
	if not _shoe_commitment.is_empty():
		_reveal_current_shoe()
	_shuffle_shoe()
	_persist_shoe(false)
	NetAPI.rpc("notify_bj_shoe_commitment", _shoe_commitment, _shoe.size())

func _shuffle_shoe(seed: String = "", nonce: String = "") -> void:
	_shoe_seed = seed if not seed.is_empty() else BlackjackFairness.secure_token()
	_shoe_nonce = nonce if not nonce.is_empty() else BlackjackFairness.secure_token(16)
	_shoe_commitment = BlackjackFairness.commitment(_shoe_seed, _shoe_nonce)
	_shoe = BlackjackFairness.make_shoe(_shoe_seed, _shoe_nonce)
	_shoe_dealt.clear()
	_shoe_audit.clear()

func _draw_card(actor: String, action: String) -> Dictionary:
	var card: Dictionary = _shoe.pop_back()
	_shoe_dealt.append(card)
	_shoe_audit.append({"actor": actor, "action": action, "card": card})
	_persist_shoe(false)
	return card

func _reveal_current_shoe() -> void:
	_persist_shoe(true)
	NetAPI.rpc("notify_bj_shoe_revealed", _shoe_commitment, _shoe_seed, _shoe_nonce, _shoe_dealt, _shoe_audit)

func _persist_shoe(revealed: bool) -> void:
	var auth := GameServer.get_node_or_null("AuthServer")
	if auth == null or auth._db == null:
		return
	if revealed:
		auth._db.query_with_bindings(
			"UPDATE blackjack_shoes SET dealt_cards = ?, audit_log = ?, revealed_at = ? WHERE commitment = ?",
			[JSON.stringify(_shoe_dealt), JSON.stringify(_shoe_audit), int(Time.get_unix_time_from_system()), _shoe_commitment]
		)
		return
	auth._db.query_with_bindings("""
		INSERT INTO blackjack_shoes (commitment, seed, nonce, dealt_cards, audit_log, created_at)
		VALUES (?, ?, ?, ?, ?, ?)
		ON CONFLICT(commitment) DO UPDATE SET dealt_cards = excluded.dealt_cards, audit_log = excluded.audit_log
	""", [_shoe_commitment, _shoe_seed, _shoe_nonce, JSON.stringify(_shoe_dealt), JSON.stringify(_shoe_audit), int(Time.get_unix_time_from_system())])

func _broadcast_shoe_count() -> void:
	NetAPI.rpc("notify_bj_shoe_count", _shoe.size())

func _val(hand: Array) -> int:
	var total := 0
	var aces  := 0
	for card in hand:
		var r: int = card["rank"]
		if r == 0:
			aces  += 1
			total += 11
		elif r >= 9:
			total += 10
		else:
			total += r + 1
	while total > 21 and aces > 0:
		total -= 10
		aces  -= 1
	return total

func _in_player_turn(session: PlayerSession) -> bool:
	return session != null and session.get_meta("bj_state", -1) == State.PLAYER_TURN

func _err(peer_id: int, msg: String) -> void:
	NetAPI.rpc_id(peer_id, "notify_bj_error", msg)

func _save_coins(session: PlayerSession) -> void:
	var auth := GameServer.get_node_or_null("AuthServer")
	if auth and auth._db:
		auth._db.query_with_bindings(
			"UPDATE players SET coins = ? WHERE username = ?",
			[session.coins, session.username]
		)
