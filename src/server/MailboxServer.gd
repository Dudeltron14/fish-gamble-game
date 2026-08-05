extends Node

const MAX_LENGTH := 240

func handle_fetch(peer_id: int) -> void:
	var session := _session_at_mailbox(peer_id)
	if session == null: return
	var auth := _auth()
	if auth == null: return
	auth._db.query_with_bindings("SELECT id, sender_username, recipient_username, recipient_list, body, sent_at, coin_amount, read_at, claimed_at FROM mailbox_messages WHERE recipient_username = ? AND deleted_at = 0 ORDER BY id DESC LIMIT 50", [session.username])
	var messages: Array = auth._db.query_result.duplicate(true)
	auth._db.query("SELECT username FROM players ORDER BY username COLLATE NOCASE")
	NetAPI.rpc_id(peer_id, "notify_mailbox_loaded", messages, auth._db.query_result)
	_send_unread(peer_id, session.username)

func handle_unread(peer_id: int) -> void:
	var session := GameServer.get_authenticated_session(peer_id)
	if session:
		_send_unread(peer_id, session.username)

func handle_send(peer_id: int, recipients: Array, body: String, coin_amount: int = 0) -> void:
	var session := _session_at_mailbox(peer_id)
	if session == null: return
	body = body.strip_escapes().strip_edges().replace("\n", " ").replace("\r", " ").left(MAX_LENGTH)
	coin_amount = maxi(coin_amount, 0)
	var names: Array[String] = []
	for value in recipients:
		var username := str(value).strip_edges()
		if not username.is_empty() and username != session.username and not names.has(username):
			names.append(username)
	if names.size() > 8:
		NetAPI.rpc_id(peer_id, "notify_mailbox_result", false, "A letter can have at most 8 recipients."); return
	if names.is_empty() or body.is_empty():
		NetAPI.rpc_id(peer_id, "notify_mailbox_result", false, "Choose another player and write a message."); return
	var auth := _auth()
	if auth == null: return
	for username in names:
		auth._db.query_with_bindings("SELECT 1 FROM players WHERE username = ?", [username])
		if auth._db.query_result.is_empty():
			NetAPI.rpc_id(peer_id, "notify_mailbox_result", false, "That player does not exist: %s." % username); return
	var total_coins := coin_amount * names.size()
	if total_coins > session.coins:
		NetAPI.rpc_id(peer_id, "notify_mailbox_result", false, "Not enough coins to attach that amount."); return
	if total_coins > 0:
		session.coins -= total_coins
		auth._db.query_with_bindings("UPDATE players SET coins = ? WHERE username = ?", [session.coins, session.username])
		NetAPI.rpc_id(peer_id, "notify_coin_balance", session.coins)
	var recipient_list := JSON.stringify(names)
	for username in names:
		auth._db.query_with_bindings("INSERT INTO mailbox_messages (sender_username, recipient_username, recipient_list, body, sent_at, coin_amount) VALUES (?, ?, ?, ?, ?, ?)", [session.username, username, recipient_list, body, int(Time.get_unix_time_from_system()), coin_amount])
	var progression := GameServer.get_node_or_null("ProgressionServer")
	if progression:
		for username in names: progression.record_mail(session, username)
	NetAPI.rpc_id(peer_id, "notify_mailbox_result", true, "Letter sent to %d %s%s." % [names.size(), "player" if names.size() == 1 else "players", " with %d gold each" % coin_amount if coin_amount > 0 else ""])
	handle_fetch(peer_id)

func handle_mark_read(peer_id: int, message_id: int) -> void:
	var session := _session_at_mailbox(peer_id)
	if session == null: return
	var auth := _auth()
	if auth == null: return
	auth._db.query_with_bindings("UPDATE mailbox_messages SET read_at = ? WHERE id = ? AND recipient_username = ? AND read_at = 0", [int(Time.get_unix_time_from_system()), message_id, session.username])
	_send_unread(peer_id, session.username)

func handle_claim_coins(peer_id: int, message_id: int) -> void:
	var session := _session_at_mailbox(peer_id)
	if session == null: return
	var auth := _auth()
	if auth == null: return
	auth._db.query_with_bindings("SELECT coin_amount, claimed_at FROM mailbox_messages WHERE id = ? AND recipient_username = ? AND deleted_at = 0", [message_id, session.username])
	if auth._db.query_result.is_empty() or int(auth._db.query_result[0].claimed_at) > 0 or int(auth._db.query_result[0].coin_amount) <= 0:
		NetAPI.rpc_id(peer_id, "notify_mailbox_result", false, "No coins are available on that letter."); return
	var coins := int(auth._db.query_result[0].coin_amount)
	auth._db.query_with_bindings("UPDATE mailbox_messages SET claimed_at = ? WHERE id = ? AND recipient_username = ? AND claimed_at = 0 AND coin_amount > 0", [int(Time.get_unix_time_from_system()), message_id, session.username])
	auth._db.query("SELECT changes() AS claimed")
	if auth._db.query_result.is_empty() or int(auth._db.query_result[0].claimed) != 1:
		NetAPI.rpc_id(peer_id, "notify_mailbox_result", false, "Those coins were already claimed."); return
	session.coins += coins
	auth._db.query_with_bindings("UPDATE players SET coins = ? WHERE username = ?", [session.coins, session.username])
	NetAPI.rpc_id(peer_id, "notify_coin_balance", session.coins)
	NetAPI.rpc_id(peer_id, "notify_mailbox_result", true, "Claimed %d gold." % coins)
	handle_fetch(peer_id)

func handle_delete(peer_id: int, message_id: int) -> void:
	var session := _session_at_mailbox(peer_id)
	if session == null: return
	var auth := _auth()
	if auth == null: return
	auth._db.query_with_bindings("UPDATE mailbox_messages SET deleted_at = ? WHERE id = ? AND recipient_username = ?", [int(Time.get_unix_time_from_system()), message_id, session.username])
	handle_fetch(peer_id)

func _send_unread(peer_id: int, username: String) -> void:
	var auth := _auth()
	if auth == null: return
	auth._db.query_with_bindings("SELECT COUNT(*) AS unread_count FROM mailbox_messages WHERE recipient_username = ? AND read_at = 0 AND deleted_at = 0", [username])
	NetAPI.rpc_id(peer_id, "notify_mailbox_unread", int(auth._db.query_result[0].unread_count) if not auth._db.query_result.is_empty() else 0)

func _auth() -> Node:
	var auth := GameServer.get_node_or_null("AuthServer")
	return auth if auth != null and auth._db != null else null

func _session_at_mailbox(peer_id: int) -> PlayerSession:
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null or session.current_zone != "MailboxZone":
		NetAPI.rpc_id(peer_id, "notify_mailbox_result", false, "Stand by a mailbox.")
		return null
	return session
