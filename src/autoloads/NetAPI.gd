extends Node

signal login_result(ok: bool, reason: String, coins: int)
signal register_result(ok: bool, reason: String)
signal fishing_start(ok: bool, fish_id: String, difficulty: float, cast_speed: float)
signal fishing_result(caught: bool, fish_id: String, earned: int, new_balance: int)
signal shop_result(ok: bool, reason: String, new_balance: int)
signal equip_result(ok: bool, item_id: String, slot: String)
signal inventory_loaded(items: Dictionary)
signal inventory_updated(item_id: String, new_qty: int)
signal bj_deal(player_cards: Array, dealer_visible: Dictionary, bet: int, balance: int)
signal bj_hit(card: Dictionary, new_val: int)
signal bj_dealer_reveal(full_hand: Array, value: int)
signal bj_dealer_card(card: Dictionary, value: int)
signal bj_result(outcome: String, dealer_hand: Array, payout: int, new_balance: int)
signal bj_error(msg: String)

# ── Client → Server ───────────────────────────────────────────────────────────
# call_local so that in Host & Play mode the host (peer 1 = server+client)
# can call these on itself. get_remote_sender_id() returns 0 on local calls,
# so we fall back to peer_id = 1 (the host).

@rpc("any_peer", "call_local", "reliable")
func request_login(username: String, pw_hash: String) -> void:
	if not multiplayer.is_server(): return
	var auth := _srv("AuthServer")
	if auth: auth.handle_login(_peer_id(), username, pw_hash)

@rpc("any_peer", "call_local", "reliable")
func request_register(username: String, pw_hash: String) -> void:
	if not multiplayer.is_server(): return
	var auth := _srv("AuthServer")
	if auth: auth.handle_register(_peer_id(), username, pw_hash)

@rpc("any_peer", "call_local", "reliable")
func c2s_world_ready() -> void:
	if not multiplayer.is_server(): return
	var peer_id := _peer_id()
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null: return
	for world in get_tree().get_nodes_in_group("world"):
		world.spawn_player(peer_id, session.username)

@rpc("any_peer", "call_local", "reliable")
func c2s_zone_changed(zone_name: String) -> void:
	if not multiplayer.is_server(): return
	var s := GameServer.get_authenticated_session(_peer_id())
	if s: s.current_zone = zone_name

@rpc("any_peer", "call_local", "reliable")
func c2s_fishing_start() -> void:
	if not multiplayer.is_server(): return
	var f := _srv("FishingServer")
	if f: f.handle_start(_peer_id())

@rpc("any_peer", "call_local", "reliable")
func c2s_fishing_result(succeeded: bool) -> void:
	if not multiplayer.is_server(): return
	var f := _srv("FishingServer")
	if f: f.handle_result(_peer_id(), succeeded)

@rpc("any_peer", "call_local", "reliable")
func c2s_equip(item_id: String) -> void:
	if not multiplayer.is_server(): return
	var s := _srv("ShopServer")
	if s: s.handle_equip(_peer_id(), item_id)

@rpc("any_peer", "call_local", "reliable")
func c2s_shop_buy(item_id: String) -> void:
	if not multiplayer.is_server(): return
	var s := _srv("ShopServer")
	if s: s.handle_buy(_peer_id(), item_id)

@rpc("any_peer", "call_local", "reliable")
func c2s_bj_bet(amount: int) -> void:
	if not multiplayer.is_server(): return
	var bj := _srv("BlackjackServer")
	if bj: bj.handle_bet(_peer_id(), amount)

@rpc("any_peer", "call_local", "reliable")
func c2s_bj_hit() -> void:
	if not multiplayer.is_server(): return
	var bj := _srv("BlackjackServer")
	if bj: bj.handle_hit(_peer_id())

@rpc("any_peer", "call_local", "reliable")
func c2s_bj_stand() -> void:
	if not multiplayer.is_server(): return
	var bj := _srv("BlackjackServer")
	if bj: bj.handle_stand(_peer_id())

@rpc("any_peer", "call_local", "reliable")
func c2s_bj_double() -> void:
	if not multiplayer.is_server(): return
	var bj := _srv("BlackjackServer")
	if bj: bj.handle_double(_peer_id())

# ── Server → Client ───────────────────────────────────────────────────────────
# call_local so that in Host & Play mode, rpc_id(1, ...) executes locally
# on the host (who is both server and client).

@rpc("authority", "call_local", "reliable")
func notify_login(ok: bool, reason: String, coins: int) -> void:
	if multiplayer.is_server(): return
	login_result.emit(ok, reason, coins)

@rpc("authority", "call_local", "reliable")
func notify_register(ok: bool, reason: String) -> void:
	if multiplayer.is_server(): return
	register_result.emit(ok, reason)

@rpc("authority", "call_local", "reliable")
func notify_fishing_start(ok: bool, fish_id: String, difficulty: float, cast_speed: float) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	fishing_start.emit(ok, fish_id, difficulty, cast_speed)

@rpc("authority", "call_local", "reliable")
func notify_fishing_result(caught: bool, fish_id: String, earned: int, new_balance: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	fishing_result.emit(caught, fish_id, earned, new_balance)

@rpc("authority", "call_local", "reliable")
func notify_shop_result(ok: bool, reason: String, new_balance: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	shop_result.emit(ok, reason, new_balance)

@rpc("authority", "call_local", "reliable")
func notify_equip_result(ok: bool, item_id: String, slot: String) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	equip_result.emit(ok, item_id, slot)

@rpc("authority", "call_local", "reliable")
func notify_inventory_loaded(items: Dictionary) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	GameManager.set_owned_items(items)
	inventory_loaded.emit(items)

@rpc("authority", "call_local", "reliable")
func notify_inventory_updated(item_id: String, new_qty: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	GameManager.set_owned(item_id, new_qty)
	inventory_updated.emit(item_id, new_qty)

@rpc("authority", "call_local", "reliable")
func notify_bj_deal(player_cards: Array, dealer_visible: Dictionary, bet: int, balance: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	bj_deal.emit(player_cards, dealer_visible, bet, balance)

@rpc("authority", "call_local", "reliable")
func notify_bj_hit(card: Dictionary, new_val: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	bj_hit.emit(card, new_val)

@rpc("authority", "call_local", "reliable")
func notify_bj_dealer_reveal(full_hand: Array, value: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	bj_dealer_reveal.emit(full_hand, value)

@rpc("authority", "call_local", "reliable")
func notify_bj_dealer_card(card: Dictionary, value: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	bj_dealer_card.emit(card, value)

@rpc("authority", "call_local", "reliable")
func notify_bj_result(outcome: String, dealer_hand: Array, payout: int, new_balance: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	bj_result.emit(outcome, dealer_hand, payout, new_balance)

@rpc("authority", "call_local", "reliable")
func notify_bj_error(msg: String) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	bj_error.emit(msg)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _srv(server_name: String) -> Node:
	return GameServer.get_node_or_null(server_name)

func _peer_id() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else 1  # 0 = local call (host mode), fall back to peer 1
