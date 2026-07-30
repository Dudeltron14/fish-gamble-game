class_name TableManager extends Node

# Reusable casino-table ownership only. Individual games keep their rules.
var _tables: Dictionary = {}

func register_table(table_id: String, game_id: String, zone_name: String, seat_count: int) -> void:
	assert(not table_id.is_empty())
	assert(seat_count > 0)
	var seats: Array = []
	for seat_number: int in seat_count:
		seats.append({"index": seat_number, "peer_id": 0, "public": {}})
	_tables[table_id] = {"id": table_id, "game_id": game_id, "zone": zone_name, "phase": "waiting", "active_seat": -1, "turn_order": [], "turn_index": -1, "seats": seats, "watchers": {}}

func watch(table_id: String, peer_id: int) -> bool:
	var table: Dictionary = _tables.get(table_id, {})
	if table.is_empty():
		return false
	table["watchers"][peer_id] = true
	return true

func unwatch(table_id: String, peer_id: int) -> bool:
	var table: Dictionary = _tables.get(table_id, {})
	if table.is_empty():
		return false
	return table["watchers"].erase(peer_id)

func join(table_id: String, peer_id: int) -> int:
	var table: Dictionary = _tables.get(table_id, {})
	if table.is_empty():
		return -1
	var seats: Array = table["seats"]
	for seat: Dictionary in seats:
		if int(seat["peer_id"]) == peer_id:
			return int(seat["index"])
	for seat: Dictionary in seats:
		if int(seat["peer_id"]) == 0:
			seat["peer_id"] = peer_id
			seat["public"] = {}
			return int(seat["index"])
	return -1

func leave(table_id: String, peer_id: int) -> bool:
	var table: Dictionary = _tables.get(table_id, {})
	if table.is_empty():
		return false
	var seats: Array = table["seats"]
	for seat: Dictionary in seats:
		if int(seat["peer_id"]) == peer_id:
			seat["peer_id"] = 0
			seat["public"] = {}
			if int(table["active_seat"]) == int(seat["index"]):
				table["active_seat"] = -1
			return true
	return false

func remove_peer(peer_id: int) -> Array[String]:
	var left_tables: Array[String] = []
	for table_id: String in _tables:
		var left_seat := leave(table_id, peer_id)
		var left_audience := unwatch(table_id, peer_id)
		if left_seat or left_audience:
			left_tables.append(table_id)
	return left_tables

func is_seated(table_id: String, peer_id: int) -> bool:
	return seat_index(table_id, peer_id) >= 0

func seat_index(table_id: String, peer_id: int) -> int:
	var table: Dictionary = _tables.get(table_id, {})
	if table.is_empty():
		return -1
	for seat: Dictionary in table["seats"]:
		if int(seat["peer_id"]) == peer_id:
			return int(seat["index"])
	return -1

func occupied_peers(table_id: String) -> Array[int]:
	var peers: Array[int] = []
	var table: Dictionary = _tables.get(table_id, {})
	if table.is_empty():
		return peers
	for seat: Dictionary in table["seats"]:
		var peer_id: int = int(seat["peer_id"])
		if peer_id != 0:
			peers.append(peer_id)
	return peers

func recipients(table_id: String) -> Array[int]:
	var peers: Array[int] = occupied_peers(table_id)
	var table: Dictionary = _tables.get(table_id, {})
	if table.is_empty():
		return peers
	for peer_id: int in table["watchers"]:
		if not peers.has(peer_id):
			peers.append(peer_id)
	return peers

func set_phase(table_id: String, phase: String) -> void:
	var table: Dictionary = _tables.get(table_id, {})
	if not table.is_empty():
		table["phase"] = phase

func set_active_seat(table_id: String, seat: int) -> void:
	var table: Dictionary = _tables.get(table_id, {})
	if not table.is_empty():
		table["active_seat"] = seat

func set_turn_order(table_id: String, peers: Array[int]) -> void:
	var table: Dictionary = _tables.get(table_id, {})
	if table.is_empty():
		return
	table["turn_order"] = peers.duplicate()
	table["turn_index"] = -1
	table["active_seat"] = -1

func next_turn_peer(table_id: String) -> int:
	var table: Dictionary = _tables.get(table_id, {})
	if table.is_empty():
		return 0
	var order: Array = table["turn_order"]
	var index: int = int(table["turn_index"]) + 1
	table["turn_index"] = index
	if index >= order.size():
		table["active_seat"] = -1
		return 0
	var peer_id: int = int(order[index])
	table["active_seat"] = seat_index(table_id, peer_id)
	return peer_id

func current_turn_peer(table_id: String) -> int:
	var table: Dictionary = _tables.get(table_id, {})
	if table.is_empty():
		return 0
	var index: int = int(table["turn_index"])
	var order: Array = table["turn_order"]
	return int(order[index]) if index >= 0 and index < order.size() else 0

func clear_turns(table_id: String) -> void:
	set_turn_order(table_id, [])

func set_seat_public(table_id: String, peer_id: int, public_state: Dictionary) -> void:
	var table: Dictionary = _tables.get(table_id, {})
	if table.is_empty():
		return
	for seat: Dictionary in table["seats"]:
		if int(seat["peer_id"]) == peer_id:
			seat["public"] = public_state.duplicate(true)
			return

func snapshot(table_id: String) -> Dictionary:
	var table: Dictionary = _tables.get(table_id, {})
	if table.is_empty():
		return {}
	var public_seats: Array = []
	for seat: Dictionary in table["seats"]:
		var peer_id: int = int(seat["peer_id"])
		var username := ""
		if peer_id != 0:
			var session: PlayerSession = GameServer.get_session(peer_id)
			username = session.username if session else str(seat["public"].get("username", "Player"))
		public_seats.append({"index": int(seat["index"]), "occupied": peer_id != 0, "username": username, "state": Dictionary(seat["public"]).duplicate(true)})
	return {"id": table["id"], "game_id": table["game_id"], "phase": table["phase"], "active_seat": table["active_seat"], "seats": public_seats}
