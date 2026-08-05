extends SceneTree

const FAIRNESS := preload("res://src/server/BlackjackFairness.gd")

func _init() -> void:
	_check()

func _check() -> void:
	var server: Node = load("res://src/server/BlackjackServer.gd").new()
	var busts := 0
	const HANDS := 2_000
	for hand_index in HANDS:
		var shoe := FAIRNESS.make_shoe("%064x" % hand_index, "dealer-odds-%d" % hand_index)
		var dealer: Array = [shoe.pop_back(), shoe.pop_back()]
		while server._val(dealer) < 17:
			dealer.append(shoe.pop_back())
		if server._val(dealer) > 21:
			busts += 1
	var bust_rate: float = float(busts) / HANDS
	print("Dealer S17 bust rate: %.2f%%" % (bust_rate * 100.0))
	assert(bust_rate > 0.25 and bust_rate < 0.32, "Dealer bust rate %.3f outside standard S17 range" % bust_rate)
	server.free()
	quit()
