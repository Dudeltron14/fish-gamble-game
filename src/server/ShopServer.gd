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
	_persist(session, item_id)
	NetAPI.rpc_id(peer_id, "notify_shop_result", true, "Purchased %s!" % item.display_name, session.coins)

func _persist(session: PlayerSession, item_id: String) -> void:
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
		ON CONFLICT DO UPDATE SET quantity = quantity + 1
	""", [session.username, item_id])
