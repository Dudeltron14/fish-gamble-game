extends SceneTree

func _init() -> void:
	call_deferred("_check")

func _check() -> void:
	var server_root: Node = root.get_node_or_null("GameServer")
	assert(server_root != null)
	server_root.init_server()
	await process_frame
	# Keep this logic test isolated from the local player database.
	var auth: Node = server_root.get_node("AuthServer")
	auth._db = null
	var session_script: Script = load("res://src/server/PlayerSession.gd")
	var first: PlayerSession = session_script.new(101)
	first.authenticated = true
	first.username = "First"
	first.current_zone = "CasinoZone"
	first.coins = 100
	var second: PlayerSession = session_script.new(102)
	second.authenticated = true
	second.username = "Second"
	second.current_zone = "CasinoZone"
	second.coins = 100
	server_root.sessions[101] = first
	server_root.sessions[102] = second
	var blackjack: Node = server_root.get_node("BlackjackServer")
	blackjack._shuffle_shoe("00112233445566778899aabbccddeeff", "table-round")
	blackjack.handle_table_enter(101)
	blackjack.handle_table_enter(102)
	blackjack.handle_bet(101, 10)
	blackjack.handle_bet(102, 10)
	assert(blackjack._next_action_seconds() > 0.0)
	blackjack._start_round()
	assert(blackjack._round_id == 1 and blackjack._hands.size() == 2)
	assert(blackjack._shoe_dirty and not blackjack._shoe_persist_timer.is_stopped())
	if blackjack._phase == blackjack.Phase.PLAYER_TURNS:
		assert(blackjack._next_action_seconds() > 0.0)
		var tables: Node = server_root.get_node("TableManager")
		var active_peer: int = tables.current_turn_peer("blackjack_harbor_1")
		var waiting_peer: int = 102 if active_peer == 101 else 101
		var waiting_cards: int = blackjack._hands[waiting_peer]["cards"].size()
		blackjack.handle_hit(waiting_peer)
		assert(blackjack._hands[waiting_peer]["cards"].size() == waiting_cards)
		blackjack.handle_stand(active_peer)
		if blackjack._phase == blackjack.Phase.PLAYER_TURNS:
			assert(tables.current_turn_peer("blackjack_harbor_1") == waiting_peer)
			blackjack.handle_stand(waiting_peer)
			assert(blackjack._phase == blackjack.Phase.RESULTS)
			assert(blackjack._turn_timer.is_stopped())
			assert(is_zero_approx(blackjack._next_action_seconds()))
	blackjack._reset_round()
	server_root.get_node("TableManager").leave("blackjack_harbor_1", 102)
	blackjack.handle_bet(101, 10)
	assert(blackjack._phase != blackjack.Phase.BETTING)
	assert(blackjack._round_timer.is_stopped())
	if blackjack._phase == blackjack.Phase.PLAYER_TURNS:
		assert(blackjack._turn_timer.is_stopped())
	quit()
