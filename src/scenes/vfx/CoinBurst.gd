extends Node2D
class_name CoinBurst

const FRAME_SIZE := Vector2i(64, 64)
const FRAME_COUNT := 31
const FPS := 30.0
const FALLING_COIN_SCRIPT := preload("res://src/scenes/vfx/FallingCoin.gd")

@onready var sprite: Sprite2D = $Sprite2D

var _elapsed := 0.0
var _frame := -1
var _cycles := 1
var _completed_loops := 0

func configure(cycles: int) -> void:
	_cycles = maxi(1, cycles)

func total_duration() -> float:
	return float(FRAME_COUNT * _cycles) / FPS

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, FRAME_SIZE)
	_set_frame(0)

func _process(delta: float) -> void:
	_elapsed += delta
	var next_frame := int(_elapsed * FPS)
	var completed_loops := mini(next_frame / FRAME_COUNT, _cycles)
	while _completed_loops < completed_loops:
		_spawn_falling_coins()
		_completed_loops += 1
	if next_frame >= FRAME_COUNT * _cycles:
		queue_free()
		return
	_set_frame(next_frame % FRAME_COUNT)

func _spawn_falling_coins() -> void:
	for i in 3:
		var coin := FALLING_COIN_SCRIPT.new()
		get_parent().add_child(coin)
		coin.global_position = global_position + Vector2(randf_range(-20.0, 20.0), randf_range(-12.0, 12.0))
		coin.scale = scale * 0.5
		coin.launch(Vector2(randf_range(-180.0, 180.0), randf_range(-340.0, -180.0)))

func _set_frame(frame: int) -> void:
	if frame == _frame:
		return
	_frame = frame
	sprite.region_rect = Rect2(Vector2(frame * FRAME_SIZE.x, 0), FRAME_SIZE)
