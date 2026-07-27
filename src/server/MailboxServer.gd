extends Node

const MAX_LENGTH := 240

func handle_fetch(peer_id: int) -> void:
	var session := _session_at_mailbox(peer_id)
	if session == null: return
	var auth := GameServer.get_node_or_null("AuthServer")
	if auth == null or auth._db == null: return
	auth._db.query_with_bindings("SELECT sender_username, body, sent_at FROM mailbox_messages WHERE recipient_username = ? ORDER BY id DESC LIMIT 50", [session.username])
	NetAPI.rpc_id(peer_id, "notify_mailbox_loaded", auth._db.query_result)

func handle_send(peer_id: int, recipient: String, body: String) -> void:
	var session := _session_at_mailbox(peer_id)
	if session == null: return
	recipient = recipient.strip_edges()
	body = body.strip_escapes().strip_edges().replace("\n", " ").replace("\r", " ").left(MAX_LENGTH)
	if recipient.is_empty() or body.is_empty() or recipient == session.username:
		NetAPI.rpc_id(peer_id, "notify_mailbox_result", false, "Choose another player and write a message."); return
	var auth := GameServer.get_node_or_null("AuthServer")
	if auth == null or auth._db == null: return
	auth._db.query_with_bindings("SELECT 1 FROM players WHERE username = ?", [recipient])
	if auth._db.query_result.is_empty():
		NetAPI.rpc_id(peer_id, "notify_mailbox_result", false, "That player does not exist."); return
	auth._db.query_with_bindings("INSERT INTO mailbox_messages (sender_username, recipient_username, body, sent_at) VALUES (?, ?, ?, ?)", [session.username, recipient, body, int(Time.get_unix_time_from_system())])
	var progression := GameServer.get_node_or_null("ProgressionServer")
	if progression: progression.record_mail(session, recipient)
	NetAPI.rpc_id(peer_id, "notify_mailbox_result", true, "Message sent to %s." % recipient)
	handle_fetch(peer_id)

func _session_at_mailbox(peer_id: int) -> PlayerSession:
	var session := GameServer.get_authenticated_session(peer_id)
	if session == null or session.current_zone != "MailboxZone":
		NetAPI.rpc_id(peer_id, "notify_mailbox_result", false, "Stand by a mailbox.")
		return null
	return session
