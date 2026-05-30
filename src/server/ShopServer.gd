extends Node

func handle_buy(peer_id: int, item_id: String) -> void:
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null or session.current_zone != "ShopZone":
		NetAPI.rpc_id(peer_id, "notify_shop_result", false, "Not in shop.", session.coins if session else 0)
		return

	var item: ItemData = ItemRegistry.get_item(item_id)
	if item == null or item.buy_price <= 0:
		NetAPI.rpc_id(peer_id, "notify_shop_result", false, "Item not for sale.", session.coins)
		return

	if session.coins < item.buy_price:
		NetAPI.rpc_id(peer_id, "notify_shop_result", false, "Not enough coins.", session.coins)
		return

	session.coins -= item.buy_price
	session.add_owned(item_id, 1)
	_persist_buy(session, item_id)
	NetAPI.rpc_id(peer_id, "notify_inventory_updated", item_id, session.get_owned(item_id))
	NetAPI.rpc_id(peer_id, "notify_shop_result", true, "Purchased %s!" % item.display_name, session.coins)

func handle_equip(peer_id: int, item_id: String) -> void:
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null:
		return
	if session.get_owned(item_id) <= 0:
		NetAPI.rpc_id(peer_id, "notify_equip_result", false, item_id, "")
		return
	var item: ItemData = ItemRegistry.get_item(item_id)
	if item == null:
		NetAPI.rpc_id(peer_id, "notify_equip_result", false, item_id, "")
		return
	var slot := ""
	if item is RodData:
		session.equipped_rod_id = item_id;    slot = "rod"
	elif item is BaitData:
		session.equipped_bait_id = item_id;   slot = "bait"
	elif item is TackleData:
		session.equipped_tackle_id = item_id
		session.hook_durability = (item as TackleData).durability
		slot = "tackle"
		NetAPI.rpc_id(peer_id, "notify_hook_durability", session.hook_durability, session.hook_durability)
	else:
		NetAPI.rpc_id(peer_id, "notify_equip_result", false, item_id, "")
		return

	session.add_owned(item_id, -1)
	_persist_decrement(session, item_id)
	NetAPI.rpc_id(peer_id, "notify_inventory_updated", item_id, session.get_owned(item_id))
	NetAPI.rpc_id(peer_id, "notify_equip_result", true, item_id, slot)

# ── Persistence (DB only, session is authoritative) ───────────────────────────

func _persist_buy(session: PlayerSession, item_id: String) -> void:
	var auth := GameServer.get_node_or_null("AuthServer")
	if auth == null or auth._db == null:
		return
	auth._db.query_with_bindings(
		"UPDATE players SET coins = ? WHERE username = ?",
		[session.coins, session.username]
	)
	auth._db.query_with_bindings("""
		INSERT INTO inventory (player_id, item_id, quantity)
		VALUES ((SELECT id FROM players WHERE username = ?), ?, 1)
		ON CONFLICT(player_id, item_id) DO UPDATE SET quantity = quantity + 1
	""", [session.username, item_id])

func _persist_decrement(session: PlayerSession, item_id: String) -> void:
	var auth := GameServer.get_node_or_null("AuthServer")
	if auth == null or auth._db == null:
		return
	auth._db.query_with_bindings("""
		UPDATE inventory SET quantity = MAX(0, quantity - 1)
		WHERE player_id = (SELECT id FROM players WHERE username = ?)
		AND item_id = ?
	""", [session.username, item_id])
