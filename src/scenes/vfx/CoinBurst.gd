extends Node2D

const FRAME_SIZE := Vector2i(64, 64)
const FRAME_COUNT := 31
const FPS := 30.0

@onready var sprite: Sprite2D = $Sprite2D

var _elapsed := 0.0
var _frame := -1

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, FRAME_SIZE)
	_set_frame(0)

func _process(delta: float) -> void:
	_elapsed += delta
	var next_frame := int(_elapsed * FPS)
	if next_frame >= FRAME_COUNT:
		queue_free()
		return
	_set_frame(next_frame)

func _set_frame(frame: int) -> void:
	if frame == _frame:
		return
	_frame = frame
	sprite.region_rect = Rect2(Vector2(frame * FRAME_SIZE.x, 0), FRAME_SIZE)
