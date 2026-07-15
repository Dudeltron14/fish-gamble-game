extends SceneTree

const MAGIC_BAIT := preload("res://src/resources/baits/magic_bait.tres")

func _init() -> void:
	var weights: Dictionary = MAGIC_BAIT.get("rarity_weights")
	assert(float(weights.get("common", -1.0)) == 0.0)
	quit()
