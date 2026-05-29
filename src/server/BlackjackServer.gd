extends Node

enum State { PLAYER_TURN, DEALER_TURN }

func handle_bet(peer_id: int, amount: int) -> void:
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null or session.current_zone != "CasinoZone":
		_err(peer_id, "Not at a table."); return
	if session.has_meta("bj_state"):
		_err(peer_id, "Game already in progress."); return

	amount = clampi(amount, 1, session.coins)
	if session.coins < amount:
		_err(peer_id, "Not enough coins."); return

	session.coins -= amount
	session.set_meta("bj_bet", amount)

	var deck := _make_deck()
	deck.shuffle()
	var ph := [deck.pop_back(), deck.pop_back()]
	var dh := [deck.pop_back(), deck.pop_back()]
	session.set_meta("bj_state", State.PLAYER_TURN)
	session.set_meta("bj_deck",  deck)
	session.set_meta("bj_ph",    ph)
	session.set_meta("bj_dh",    dh)

	NetAPI.rpc_id(peer_id, "notify_bj_deal", ph, dh[0], amount, session.coins)

	if _val(ph) == 21:
		_run_dealer(peer_id, session)

func handle_hit(peer_id: int) -> void:
	var session := GameServer.get_authenticated_session(peer_id)
	if not _in_player_turn(session): return
	var deck: Array = session.get_meta("bj_deck")
	var ph: Array   = session.get_meta("bj_ph")
	var card: Dictionary = deck.pop_back()
	ph.append(card)
	session.set_meta("bj_deck", deck)
	session.set_meta("bj_ph",   ph)
	NetAPI.rpc_id(peer_id, "notify_bj_hit", card, _val(ph))
	if _val(ph) >= 21:
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
	var extra := mini(bet, session.coins)
	session.coins -= extra
	session.set_meta("bj_bet", bet + extra)
	var deck: Array = session.get_meta("bj_deck")
	var card := deck.pop_back()
	ph.append(card)
	session.set_meta("bj_deck", deck)
	session.set_meta("bj_ph",   ph)
	NetAPI.rpc_id(peer_id, "notify_bj_hit", card, _val(ph))
	_run_dealer(peer_id, session)

# ── Internal ──────────────────────────────────────────────────────────────────

func _run_dealer(peer_id: int, session: PlayerSession) -> void:
	session.set_meta("bj_state", State.DEALER_TURN)
	var deck: Array = session.get_meta("bj_deck")
	var dh: Array   = session.get_meta("bj_dh")

	NetAPI.rpc_id(peer_id, "notify_bj_dealer_reveal", dh, _val(dh))

	while _val(dh) < 17:
		var card := deck.pop_back()
		dh.append(card)
		NetAPI.rpc_id(peer_id, "notify_bj_dealer_card", card, _val(dh))

	session.set_meta("bj_dh",   dh)
	session.set_meta("bj_deck", deck)
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

	for key in ["bj_state", "bj_deck", "bj_ph", "bj_dh", "bj_bet"]:
		if session.has_meta(key):
			session.remove_meta(key)

	NetAPI.rpc_id(peer_id, "notify_bj_result", outcome, dh, payout, session.coins)

func _make_deck() -> Array:
	var d := []
	for s in 4:
		for r in 13:
			d.append({"suit": s, "rank": r})
	return d

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
