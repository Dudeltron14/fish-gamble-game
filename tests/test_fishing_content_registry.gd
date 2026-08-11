extends SceneTree

func _init() -> void:
	call_deferred("_check")

func _check() -> void:
	assert(ItemRegistry.locations.has("starter_harbor"))
	assert(ItemRegistry.get_location_for_zone("PierZone") != null)
	assert(ItemRegistry.get_location_for_zone("LighthouseRocksZone") != null)
	assert(ItemRegistry.get_location_for_zone("ReedbankZone") != null)
	assert(GameServer.FISHING_EVENTS.size() == 3)
	for event: FishingEventData in GameServer.FISHING_EVENTS:
		assert(not event.id.is_empty())
		assert(event.duration_seconds > 0)
	for location: FishingLocationData in ItemRegistry.locations.values():
		assert(not location.id.is_empty())
		assert(not location.zone_name.is_empty())
		assert(not location.fish_ids.is_empty())
		for fish_id: String in location.fish_ids:
			var fish := ItemRegistry.get_item(fish_id) as FishData
			assert(fish != null, "Missing fish resource: %s" % fish_id)
			assert(fish.icon != null, "Missing fish sprite: %s" % fish_id)
			var size := fish.catch_range()
			if fish_id != "legendary_chest" and fish_id != "legendary_key":
				assert(size.y > size.x, "Invalid size range: %s" % fish_id)
			assert(fish.rarity in ["common", "uncommon", "rare", "legendary"])
	print("Fishing content registry validation passed")
	quit()
