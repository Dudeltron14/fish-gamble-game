extends Node

signal login_result(ok: bool, reason: String, coins: int)
signal register_result(ok: bool, reason: String)
signal server_status(player_count: int, sent_ms: int)
signal leaderboard_result(entries: Array)
signal fishing_start(ok: bool, fish_id: String, difficulty: float, cast_speed: float, line_strength: float, wait_modifier: float, hook_react_bonus: float, auto_catch: bool)
signal fishing_result(caught: bool, fish_id: String, earned: int, new_balance: int, measurement: float, measurement_unit: String, personal_record: bool)
signal shop_result(ok: bool, reason: String, new_balance: int)
signal equip_result(ok: bool, item_id: String, slot: String)
signal inventory_loaded(items: Dictionary)
signal inventory_updated(item_id: String, new_qty: int)
signal equipment_loaded(rod_id: String, bait_id: String, tackle_id: String, hook_durability: int, hook_max_durability: int)
signal bait_empty()
signal hook_broken()
signal hook_durability_changed(current: int, max_val: int)
signal bj_deal(player_cards: Array, dealer_visible: Dictionary, bet: int, balance: int, deck_remaining: int)
signal bj_shuffled(deck_remaining: int)
signal bj_shoe_count(deck_remaining: int)
signal bj_shoe_commitment(commitment: String, deck_remaining: int)
signal bj_shoe_revealed(commitment: String, seed: String, nonce: String, dealt_cards: Array, audit_log: Array)
signal bj_hit(card: Dictionary, new_val: int, deck_remaining: int)
signal bj_dealer_reveal(full_hand: Array, value: int, deck_remaining: int)
signal bj_dealer_card(card: Dictionary, value: int, deck_remaining: int)
signal bj_result(outcome: String, dealer_hand: Array, payout: int, new_balance: int)
signal bj_error(msg: String)
signal mailbox_loaded(messages: Array)
signal mailbox_result(ok: bool, reason: String)
signal harbor_stats_loaded(stats: Dictionary)
signal daily_quests_loaded(ledger: Dictionary)
signal daily_quest_result(ok: bool, reason: String)

const CHAT_RANGE := 360.0
const CHAT_COOLDOWN_MS := 1_000
const CHAT_MAX_LENGTH := 48

# ── Client → Server ───────────────────────────────────────────────────────────
# call_local so that in Host & Play mode the host (peer 1 = server+client)
# can call these on itself. get_remote_sender_id() returns 0 on local calls,
# so we fall back to peer_id = 1 (the host).

@rpc("any_peer", "call_local", "reliable")
func request_login(username: String, pw_hash: String) -> void:
	if not multiplayer.is_server(): return
	var peer_id := _peer_id()
	push_warning("NetAPI: request_login from peer %d username=%s" % [peer_id, username])
	var auth := _srv("AuthServer")
	if auth:
		auth.handle_login(peer_id, username, pw_hash)
	else:
		NetAPI.rpc_id(peer_id, "notify_login", false, "Auth server unavailable.", 0)

@rpc("any_peer", "call_local", "reliable")
func request_register(username: String, pw_hash: String) -> void:
	if not multiplayer.is_server(): return
	var peer_id := _peer_id()
	push_warning("NetAPI: request_register from peer %d username=%s" % [peer_id, username])
	var auth := _srv("AuthServer")
	if auth:
		auth.handle_register(peer_id, username, pw_hash)
	else:
		NetAPI.rpc_id(peer_id, "notify_register", false, "Auth server unavailable.")

@rpc("any_peer", "call_local", "reliable")
func c2s_world_ready() -> void:
	if not multiplayer.is_server(): return
	var peer_id := _peer_id()
	push_warning("NetAPI: c2s_world_ready from peer %d" % peer_id)
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null:
		push_warning("NetAPI: world_ready ignored; peer %d is not authenticated" % peer_id)
		return
	for world in get_tree().get_nodes_in_group("world"):
		world.spawn_player(peer_id, session.username)

@rpc("any_peer", "call_local", "reliable")
func c2s_server_status(sent_ms: int) -> void:
	if not multiplayer.is_server(): return
	var peer_id := _peer_id()
	NetAPI.rpc_id(peer_id, "notify_server_status", GameServer.get_authenticated_player_count(), sent_ms)

@rpc("any_peer", "call_local", "reliable")
func c2s_leaderboard_request() -> void:
	if not multiplayer.is_server(): return
	var peer_id := _peer_id()
	NetAPI.rpc_id(peer_id, "notify_leaderboard", GameServer.get_leaderboard())

@rpc("any_peer", "call_local", "unreliable_ordered")
func c2s_player_input(input_dir: Vector2, animation: String, flip_h: bool, hidden: bool, bobber_cast_quality: float = -1.0) -> void:
	if not multiplayer.is_server(): return
	var peer_id := _peer_id()
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null:
		return
	for world in get_tree().get_nodes_in_group("world"):
		if world.has_method("apply_authoritative_player_input"):
			world.apply_authoritative_player_input(peer_id, input_dir, animation, flip_h, hidden, bobber_cast_quality)

@rpc("any_peer", "call_local", "reliable")
func c2s_zone_changed(zone_name: String) -> void:
	if not multiplayer.is_server(): return
	_refresh_peer_zone(_peer_id(), zone_name)

@rpc("any_peer", "call_local", "reliable")
func c2s_fishing_start(cast_quality: float = 1.0) -> void:
	if not multiplayer.is_server(): return
	_refresh_peer_zone(_peer_id())
	var f := _srv("FishingServer")
	if f: f.handle_start(_peer_id(), cast_quality)

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
	_refresh_peer_zone(_peer_id())
	var s := _srv("ShopServer")
	if s: s.handle_buy(_peer_id(), item_id)

@rpc("any_peer", "call_local", "reliable")
func c2s_bj_bet(amount: int) -> void:
	if not multiplayer.is_server(): return
	_refresh_peer_zone(_peer_id())
	var bj := _srv("BlackjackServer")
	if bj: bj.handle_bet(_peer_id(), amount)

@rpc("any_peer", "call_local", "reliable")
func c2s_bj_shoe_count() -> void:
	if not multiplayer.is_server(): return
	var bj := _srv("BlackjackServer")
	if bj: bj.handle_shoe_count(_peer_id())

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

@rpc("any_peer", "call_local", "reliable")
func c2s_bj_forfeit() -> void:
	if not multiplayer.is_server(): return
	var bj := _srv("BlackjackServer")
	if bj: bj.handle_forfeit(_peer_id())

@rpc("any_peer", "call_local", "reliable")
func c2s_chat_send(text: String) -> void:
	if not multiplayer.is_server(): return
	var peer_id := _peer_id()
	var sender := GameServer.get_authenticated_session(peer_id)
	if sender == null:
		return
	var message := text.strip_escapes().strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ").left(CHAT_MAX_LENGTH)
	if message.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - sender.last_chat_ms < CHAT_COOLDOWN_MS:
		return
	sender.last_chat_ms = now
	var progression := _srv("ProgressionServer")
	if progression: progression.record_chat_message(sender)
	_refresh_peer_zone(peer_id)
	for world in get_tree().get_nodes_in_group("world"):
		var sender_player := world.get_node_or_null("Players/%d" % peer_id) as Node2D
		if sender_player == null:
			continue
		for recipient_id in GameServer.sessions:
			var recipient := GameServer.get_authenticated_session(recipient_id)
			if recipient == null or recipient.current_zone != sender.current_zone:
				continue
			var recipient_player := world.get_node_or_null("Players/%d" % recipient_id) as Node2D
			if recipient_player and sender_player.global_position.distance_squared_to(recipient_player.global_position) <= CHAT_RANGE * CHAT_RANGE:
				NetAPI.rpc_id(recipient_id, "notify_chat_bubble", peer_id, message)
				if progression: progression.record_chat_received(recipient)

@rpc("any_peer", "call_local", "reliable")
func c2s_mailbox_fetch() -> void:
	if multiplayer.is_server():
		var mailbox := _srv("MailboxServer")
		if mailbox: mailbox.handle_fetch(_peer_id())

@rpc("any_peer", "call_local", "reliable")
func c2s_mailbox_send(recipient: String, body: String) -> void:
	if multiplayer.is_server():
		var mailbox := _srv("MailboxServer")
		if mailbox: mailbox.handle_send(_peer_id(), recipient, body)

@rpc("any_peer", "call_local", "reliable")
func c2s_harbor_stats() -> void:
	if multiplayer.is_server():
		var progression := _srv("ProgressionServer")
		if progression: progression.handle_stats(_peer_id())

@rpc("any_peer", "call_local", "reliable")
func c2s_daily_quests() -> void:
	if multiplayer.is_server():
		var progression := _srv("ProgressionServer")
		if progression: progression.handle_quests(_peer_id())

@rpc("any_peer", "call_local", "reliable")
func c2s_daily_quest_reroll(slot: int) -> void:
	if multiplayer.is_server():
		var progression := _srv("ProgressionServer")
		if progression: progression.handle_reroll(_peer_id(), slot)

@rpc("any_peer", "call_local", "reliable")
func c2s_daily_quest_claim(slot: int) -> void:
	if multiplayer.is_server():
		var progression := _srv("ProgressionServer")
		if progression: progression.handle_claim(_peer_id(), slot)

# ── Server → Client ───────────────────────────────────────────────────────────
# call_local so that in Host & Play mode, rpc_id(1, ...) executes locally
# on the host (who is both server and client).

@rpc("authority", "call_local", "reliable")
func notify_login(ok: bool, reason: String, coins: int) -> void:
	if multiplayer.is_server(): return
	login_result.emit(ok, reason, coins)

@rpc("authority", "call_local", "reliable")
func notify_world_player_spawned(peer_id: int, p_name: String, spawn_position: Vector2) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	for world in get_tree().get_nodes_in_group("world"):
		if world.has_method("ensure_player"):
			world.ensure_player(peer_id, p_name, spawn_position)

@rpc("authority", "call_local", "reliable")
func notify_world_player_despawned(peer_id: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	for world in get_tree().get_nodes_in_group("world"):
		if world.has_method("despawn_remote_player"):
			world.despawn_remote_player(peer_id)

@rpc("authority", "call_local", "unreliable_ordered")
func notify_player_state(peer_id: int, pos: Vector2, animation: String, flip_h: bool, hidden: bool, bobber_cast_quality: float = -1.0) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	for world in get_tree().get_nodes_in_group("world"):
		if world.has_method("apply_remote_player_state"):
			world.apply_remote_player_state(peer_id, pos, animation, flip_h, hidden, bobber_cast_quality)

@rpc("authority", "call_local", "reliable")
func notify_player_catch(peer_id: int, fish_id: String, trophy: bool = false) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	for world in get_tree().get_nodes_in_group("world"):
		if world.has_method("show_player_catch"):
			world.show_player_catch(peer_id, fish_id, trophy)

@rpc("authority", "call_local", "reliable")
func notify_chat_bubble(peer_id: int, message: String) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	for world in get_tree().get_nodes_in_group("world"):
		if world.has_method("show_player_chat_bubble"):
			world.show_player_chat_bubble(peer_id, message)

@rpc("authority", "call_local", "reliable")
func notify_mailbox_loaded(messages: Array) -> void:
	if not multiplayer.is_server():
		mailbox_loaded.emit(messages)

@rpc("authority", "call_local", "reliable")
func notify_mailbox_result(ok: bool, reason: String) -> void:
	if not multiplayer.is_server():
		mailbox_result.emit(ok, reason)

@rpc("authority", "call_local", "reliable")
func notify_harbor_stats(stats: Dictionary) -> void:
	if not multiplayer.is_server():
		harbor_stats_loaded.emit(stats)

@rpc("authority", "call_local", "reliable")
func notify_daily_quests(ledger: Dictionary) -> void:
	if not multiplayer.is_server():
		daily_quests_loaded.emit(ledger)

@rpc("authority", "call_local", "reliable")
func notify_daily_quest_result(ok: bool, reason: String) -> void:
	if not multiplayer.is_server():
		daily_quest_result.emit(ok, reason)

@rpc("authority", "call_local", "reliable")
func notify_register(ok: bool, reason: String) -> void:
	if multiplayer.is_server(): return
	register_result.emit(ok, reason)

@rpc("authority", "call_local", "reliable")
func notify_server_status(player_count: int, sent_ms: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	server_status.emit(player_count, sent_ms)

@rpc("authority", "call_local", "reliable")
func notify_leaderboard(entries: Array) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	leaderboard_result.emit(entries)

@rpc("authority", "call_local", "reliable")
func notify_fishing_start(ok: bool, fish_id: String, difficulty: float, cast_speed: float, line_strength: float, wait_modifier: float = 1.0, hook_react_bonus: float = 0.0, auto_catch: bool = false) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	fishing_start.emit(ok, fish_id, difficulty, cast_speed, line_strength, wait_modifier, hook_react_bonus, auto_catch)

@rpc("authority", "call_local", "reliable")
func notify_fishing_result(caught: bool, fish_id: String, earned: int, new_balance: int, measurement: float = 0.0, measurement_unit: String = "", personal_record: bool = false) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	fishing_result.emit(caught, fish_id, earned, new_balance, measurement, measurement_unit, personal_record)

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
func notify_equipment_loaded(rod_id: String, bait_id: String, tackle_id: String, hook_durability: int, hook_max_durability: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	GameManager.equipped_rod_id = rod_id
	GameManager.equipped_bait_id = bait_id
	GameManager.equipped_tackle_id = tackle_id
	GameManager.hook_durability = hook_durability
	GameManager.hook_max_durability = hook_max_durability
	GameManager.equipped_changed.emit()
	GameManager.hook_durability_changed.emit(hook_durability, hook_max_durability)
	equipment_loaded.emit(rod_id, bait_id, tackle_id, hook_durability, hook_max_durability)

@rpc("authority", "call_local", "reliable")
func notify_bj_shuffled(deck_remaining: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	bj_shuffled.emit(deck_remaining)

@rpc("authority", "call_local", "reliable")
func notify_bj_shoe_count(deck_remaining: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	bj_shoe_count.emit(deck_remaining)

@rpc("authority", "call_local", "reliable")
func notify_bj_shoe_commitment(commitment: String, deck_remaining: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	bj_shoe_commitment.emit(commitment, deck_remaining)

@rpc("authority", "call_local", "reliable")
func notify_bj_shoe_revealed(commitment: String, seed: String, nonce: String, dealt_cards: Array, audit_log: Array) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	bj_shoe_revealed.emit(commitment, seed, nonce, dealt_cards, audit_log)

@rpc("authority", "call_local", "reliable")
func notify_bj_deal(player_cards: Array, dealer_visible: Dictionary, bet: int, balance: int, deck_remaining: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	bj_deal.emit(player_cards, dealer_visible, bet, balance, deck_remaining)

@rpc("authority", "call_local", "reliable")
func notify_bj_hit(card: Dictionary, new_val: int, deck_remaining: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	bj_hit.emit(card, new_val, deck_remaining)

@rpc("authority", "call_local", "reliable")
func notify_bj_dealer_reveal(full_hand: Array, value: int, deck_remaining: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	bj_dealer_reveal.emit(full_hand, value, deck_remaining)

@rpc("authority", "call_local", "reliable")
func notify_bj_dealer_card(card: Dictionary, value: int, deck_remaining: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	bj_dealer_card.emit(card, value, deck_remaining)

@rpc("authority", "call_local", "reliable")
func notify_bj_result(outcome: String, dealer_hand: Array, payout: int, new_balance: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	bj_result.emit(outcome, dealer_hand, payout, new_balance)

@rpc("authority", "call_local", "reliable")
func notify_bj_error(msg: String) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	bj_error.emit(msg)

# ── Helpers ───────────────────────────────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func notify_bait_empty() -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	GameManager.equipped_bait_id = ""
	GameManager.equipped_changed.emit()
	bait_empty.emit()

@rpc("authority", "call_local", "reliable")
func notify_hook_broken() -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	GameManager.equipped_tackle_id = ""
	GameManager.hook_durability = 0
	GameManager.hook_max_durability = 0
	GameManager.equipped_changed.emit()
	GameManager.hook_durability_changed.emit(0, 0)
	hook_broken.emit()

@rpc("authority", "call_local", "reliable")
func notify_hook_durability(current: int, max_val: int) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting: return
	GameManager.hook_durability = current
	GameManager.hook_max_durability = max_val
	GameManager.hook_durability_changed.emit(current, max_val)

func _srv(server_name: String) -> Node:
	return GameServer.get_node_or_null(server_name)

func _refresh_peer_zone(peer_id: int, fallback_zone: String = "") -> void:
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null:
		return
	for world in get_tree().get_nodes_in_group("world"):
		if world.has_method("get_zone_for_peer"):
			session.current_zone = world.get_zone_for_peer(peer_id)
			return
	session.current_zone = fallback_zone

func _peer_id() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else 1  # 0 = local call (host mode), fall back to peer 1
