extends SceneTree

func _init() -> void:
	call_deferred("_check")

func _check() -> void:
	var hall: CanvasLayer = load("res://src/scenes/ui/HarborMasterStats.tscn").instantiate()
	root.add_child(hall)
	await process_frame
	hall.call("_show_stats", {
		"username": "Tester", "players": [], "career": {}, "viewer_career": {}, "coins": 0, "viewer_coins": 0, "gear": [],
		"fish": [
			{"fish_id": "uncommon_bass", "caught_count": 1, "got_away_count": 0, "best_measurement": 12.0},
			{"fish_id": "junk_boot", "caught_count": 1, "got_away_count": 0, "best_measurement": 2.0},
			{"fish_id": "legendary_key", "caught_count": 1, "got_away_count": 0, "best_measurement": 0.0},
		], "viewer_fish": []
	})
	await process_frame
	var rows: VBoxContainer = hall.get_node("Center/Panel/Margin/VBox/Tabs/FishingStats/Scroll/FishRows")
	assert(rows.get_child_count() == 6)
	for child in rows.get_children():
		if child is HBoxContainer:
			assert(child.get_combined_minimum_size().y >= 32.0)
	quit()
