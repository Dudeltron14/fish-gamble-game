extends SceneTree

func _init() -> void:
	call_deferred("_check")

func _check() -> void:
	var server_root: Node = root.get_node_or_null("GameServer")
	assert(server_root != null)
	server_root.init_server()
	await process_frame
	var fishing: Node = server_root.get_node("FishingServer")
	assert(fishing._is_local_test_mode())
	assert(fishing._pick_no_bait_fish(0.5) != null)
	var session: PlayerSession = load("res://src/server/PlayerSession.gd").new(77)
	session.authenticated = true
	session.username = "MailboxTester"
	session.current_zone = "MailboxZone"
	server_root.sessions[77] = session
	var mailbox: Node = server_root.get_node("MailboxServer")
	assert(mailbox._session_at_mailbox(77) == session)
	quit()
