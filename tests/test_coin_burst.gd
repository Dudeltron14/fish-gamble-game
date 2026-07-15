extends SceneTree

const COIN_BURST_SCRIPT := preload("res://src/scenes/vfx/CoinBurst.gd")
const FALLING_COIN_SCRIPT := preload("res://src/scenes/vfx/FallingCoin.gd")

func _init() -> void:
	var burst = COIN_BURST_SCRIPT.new()
	burst.configure(3)
	assert(is_equal_approx(burst.total_duration(), 3.1))
	burst.free()
	var coin = FALLING_COIN_SCRIPT.new()
	coin.launch(Vector2(100.0, -200.0))
	coin._process(0.1)
	assert(coin.velocity.y > -200.0)
	coin.free()
	quit()
