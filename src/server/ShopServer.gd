extends Node

func handle_buy(peer_id: int, item_id: String) -> void:
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null or session.current_zone != "ShopZone":
		NetAPI.rpc_id(peer_id, "notify_shop_result", false, "Not in shop.", session.coins if session else 0)
		return

	var item: ItemData = ItemRegistry.get_item(item_id)
	if item == null or item.buy_price <= 0:
		push_warning("ShopServer: buy rejected peer=%d item=%s found=%s price=%d" % [peer_id, item_id, str(item != null), item.buy_price if item else -1])
		NetAPI.rpc_id(peer_id, "notify_shop_result", false, "Item not for sale.", session.coins)
		return

	if session.coins < item.buy_price:
		NetAPI.rpc_id(peer_id, "notify_shop_result", false, "Not enough coins.", session.coins)
		return

	session.coins -= item.buy_price
	var qty: int = (item as BaitData).uses_per_stack if item is BaitData else 1
	session.add_owned(item_id, qty)
	var auto_equipped := _auto_equip_if_empty(peer_id, session, item, item_id)
	_persist_buy(session, item_id, qty)
	NetAPI.rpc_id(peer_id, "notify_inventory_updated", item_id, session.get_owned(item_id))
	var result_msg := "Purchased %s!" % item.display_name
	if auto_equipped:
		result_msg += " Auto-equipped."
	elif item is BaitData or item is TackleData:
		result_msg += " Equip it before fishing."
	NetAPI.rpc_id(peer_id, "notify_shop_result", true, result_msg, session.coins)

func handle_equip(peer_id: int, item_id: String) -> void:
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null:
		return
	if session.get_owned(item_id) <= 0:
		push_warning("ShopServer: equip rejected peer=%d item=%s owned=%d" % [peer_id, item_id, session.get_owned(item_id)])
		NetAPI.rpc_id(peer_id, "notify_equip_result", false, item_id, "")
		return
	var item: ItemData = ItemRegistry.get_item(item_id)
	if item == null:
		push_warning("ShopServer: equip rejected peer=%d item=%s not found" % [peer_id, item_id])
		NetAPI.rpc_id(peer_id, "notify_equip_result", false, item_id, "")
		return
	var slot := ""
	if item is RodData:
		session.equipped_rod_id = item_id;    slot = "rod"
	elif item is BaitData:
		if session.equipped_tackle_id == "treasure_magnet":
			NetAPI.rpc_id(peer_id, "notify_equip_result", false, item_id, "")
			return
		session.equipped_bait_id = item_id;   slot = "bait"
	elif item is TackleData:
		session.equipped_tackle_id = item_id
		if item_id == "treasure_magnet":
			session.equipped_bait_id = ""
		var tackle := item as TackleData
		session.hook_durability = tackle.durability
		slot = "tackle"
		NetAPI.rpc_id(peer_id, "notify_hook_durability", session.hook_durability, tackle.durability)
	else:
		NetAPI.rpc_id(peer_id, "notify_equip_result", false, item_id, "")
		return

	# Equipping is free — bait/hook counts only decrease when fishing, not when swapping
	_persist_equipment(session)
	NetAPI.rpc_id(peer_id, "notify_equip_result", true, item_id, slot)
	if item_id == "treasure_magnet":
		NetAPI.rpc_id(peer_id, "notify_equipment_loaded", session.equipped_rod_id, session.equipped_bait_id, session.equipped_tackle_id, session.hook_durability, (item as TackleData).durability)

# ── Persistence (DB only, session is authoritative) ───────────────────────────

func _persist_buy(session: PlayerSession, item_id: String, qty: int = 1) -> void:
	var auth := GameServer.get_node_or_null("AuthServer")
	if auth == null or auth._db == null:
		return
	auth._db.query_with_bindings(
		"UPDATE players SET coins = ? WHERE username = ?",
		[session.coins, session.username]
	)
	auth._db.query_with_bindings("""
		INSERT INTO inventory (player_id, item_id, quantity)
		VALUES ((SELECT id FROM players WHERE username = ?), ?, ?)
		ON CONFLICT(player_id, item_id) DO UPDATE SET quantity = quantity + ?
	""", [session.username, item_id, qty, qty])

func _persist_decrement(session: PlayerSession, item_id: String) -> void:
	var auth := GameServer.get_node_or_null("AuthServer")
	if auth == null or auth._db == null:
		return
	auth._db.query_with_bindings("""
		UPDATE inventory SET quantity = MAX(0, quantity - 1)
		WHERE player_id = (SELECT id FROM players WHERE username = ?)
		AND item_id = ?
	""", [session.username, item_id])

func _persist_equipment(session: PlayerSession) -> void:
	var auth := GameServer.get_node_or_null("AuthServer")
	if auth != null and auth.has_method("save_equipment"):
		auth.save_equipment(session)

func _auto_equip_if_empty(peer_id: int, session: PlayerSession, item: ItemData, item_id: String) -> bool:
	if item is BaitData and session.equipped_bait_id.is_empty():
		session.equipped_bait_id = item_id
		_persist_equipment(session)
		NetAPI.rpc_id(peer_id, "notify_equip_result", true, item_id, "bait")
		return true
	if item is TackleData and session.equipped_tackle_id.is_empty():
		session.equipped_tackle_id = item_id
		if item_id == "treasure_magnet":
			session.equipped_bait_id = ""
		var tackle := item as TackleData
		session.hook_durability = tackle.durability
		_persist_equipment(session)
		NetAPI.rpc_id(peer_id, "notify_hook_durability", session.hook_durability, tackle.durability)
		NetAPI.rpc_id(peer_id, "notify_equip_result", true, item_id, "tackle")
		if item_id == "treasure_magnet":
			NetAPI.rpc_id(peer_id, "notify_equipment_loaded", session.equipped_rod_id, session.equipped_bait_id, session.equipped_tackle_id, session.hook_durability, tackle.durability)
		return true
	return false
