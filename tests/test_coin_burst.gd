extends SceneTree

const COIN_BURST_SCRIPT := preload("res://src/scenes/vfx/CoinBurst.gd")

func _init() -> void:
	var burst = COIN_BURST_SCRIPT.new()
	burst.configure(3, 500.0)
	assert(is_equal_approx(burst.total_duration(), 3.1))
	burst.free()
	quit()
