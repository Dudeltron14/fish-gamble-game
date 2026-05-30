extends Node

signal login_result(ok: bool, reason: String, coins: int)
signal register_result(ok: bool, reason: String)
signal fishing_start(ok: bool, fish_id: String, difficulty: float, cast_speed: float)
signal fishing_result(caught: bool, fish_id: String, earned: int, new_balance: int)
signal shop_result(ok: bool, reason: String, new_balance: int)
signal bj_deal(player_cards: Array, dealer_visible: Dictionary, bet: int, balance: int)
signal bj_hit(card: Dictionary, new_val: int)
signal bj_dealer_reveal(full_hand: Array, value: int)
signal bj_dealer_card(card: Dictionary, value: int)
signal bj_result(outcome: String, dealer_hand: Array, payout: int, new_balance: int)
signal bj_error(msg: String)

# ── Client → Server ──────────────────────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func request_login(username: String, pw_hash: String) -> void:
	if not multiplayer.is_server(): return
	var auth := _srv("AuthServer")
	if auth: auth.handle_login(multiplayer.get_remote_sender_id(), username, pw_hash)

@rpc("any_peer", "call_remote", "reliable")
func request_register(username: String, pw_hash: String) -> void:
	if not multiplayer.is_server(): return
	var auth := _srv("AuthServer")
	if auth: auth.handle_register(multiplayer.get_remote_sender_id(), username, pw_hash)

@rpc("any_peer", "call_remote", "reliable")
func c2s_world_ready() -> void:
	if not multiplayer.is_server(): return
	var peer_id := multiplayer.get_remote_sender_id()
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null: return
	for world in get_tree().get_nodes_in_group("world"):
		world.spawn_player(peer_id, session.username)

@rpc("any_peer", "call_remote", "reliable")
func c2s_zone_changed(zone_name: String) -> void:
	if not multiplayer.is_server(): return
	var s := GameServer.get_authenticated_session(multiplayer.get_remote_sender_id())
	if s: s.current_zone = zone_name

@rpc("any_peer", "call_remote", "reliable")
func c2s_fishing_start() -> void:
	if not multiplayer.is_server(): return
	var f := _srv("FishingServer")
	if f: f.handle_start(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "reliable")
func c2s_fishing_result(succeeded: bool) -> void:
	if not multiplayer.is_server(): return
	var f := _srv("FishingServer")
	if f: f.handle_result(multiplayer.get_remote_sender_id(), succeeded)

@rpc("any_peer", "call_remote", "reliable")
func c2s_shop_buy(item_id: String) -> void:
	if not multiplayer.is_server(): return
	var s := _srv("ShopServer")
	if s: s.handle_buy(multiplayer.get_remote_sender_id(), item_id)

@rpc("any_peer", "call_remote", "reliable")
func c2s_bj_bet(amount: int) -> void:
	if not multiplayer.is_server(): return
	var bj := _srv("BlackjackServer")
	if bj: bj.handle_bet(multiplayer.get_remote_sender_id(), amount)

@rpc("any_peer", "call_remote", "reliable")
func c2s_bj_hit() -> void:
	if not multiplayer.is_server(): return
	var bj := _srv("BlackjackServer")
	if bj: bj.handle_hit(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "reliable")
func c2s_bj_stand() -> void:
	if not multiplayer.is_server(): return
	var bj := _srv("BlackjackServer")
	if bj: bj.handle_stand(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "reliable")
func c2s_bj_double() -> void:
	if not multiplayer.is_server(): return
	var bj := _srv("BlackjackServer")
	if bj: bj.handle_double(multiplayer.get_remote_sender_id())

# ── Server → Client ──────────────────────────────────────────────────────────

@rpc("authority", "call_remote", "reliable")
func notify_login(ok: bool, reason: String, coins: int) -> void:
	login_result.emit(ok, reason, coins)

@rpc("authority", "call_remote", "reliable")
func notify_register(ok: bool, reason: String) -> void:
	register_result.emit(ok, reason)

@rpc("authority", "call_remote", "reliable")
func notify_fishing_start(ok: bool, fish_id: String, difficulty: float, cast_speed: float) -> void:
	fishing_start.emit(ok, fish_id, difficulty, cast_speed)

@rpc("authority", "call_remote", "reliable")
func notify_fishing_result(caught: bool, fish_id: String, earned: int, new_balance: int) -> void:
	fishing_result.emit(caught, fish_id, earned, new_balance)

@rpc("authority", "call_remote", "reliable")
func notify_shop_result(ok: bool, reason: String, new_balance: int) -> void:
	shop_result.emit(ok, reason, new_balance)

@rpc("authority", "call_remote", "reliable")
func notify_bj_deal(player_cards: Array, dealer_visible: Dictionary, bet: int, balance: int) -> void:
	bj_deal.emit(player_cards, dealer_visible, bet, balance)

@rpc("authority", "call_remote", "reliable")
func notify_bj_hit(card: Dictionary, new_val: int) -> void:
	bj_hit.emit(card, new_val)

@rpc("authority", "call_remote", "reliable")
func notify_bj_dealer_reveal(full_hand: Array, value: int) -> void:
	bj_dealer_reveal.emit(full_hand, value)

@rpc("authority", "call_remote", "reliable")
func notify_bj_dealer_card(card: Dictionary, value: int) -> void:
	bj_dealer_card.emit(card, value)

@rpc("authority", "call_remote", "reliable")
func notify_bj_result(outcome: String, dealer_hand: Array, payout: int, new_balance: int) -> void:
	bj_result.emit(outcome, dealer_hand, payout, new_balance)

@rpc("authority", "call_remote", "reliable")
func notify_bj_error(msg: String) -> void:
	bj_error.emit(msg)

# ── Helpers ──────────────────────────────────────────────────────────────────

func _srv(server_name: String) -> Node:
	return GameServer.get_node_or_null(server_name)
