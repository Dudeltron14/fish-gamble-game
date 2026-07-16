extends Sprite2D

const GRAVITY := 1400.0
const COIN_SHEET := preload("res://assets/vfx/directional_coin_fall_sheet.png")
const FRAME_SIZE := Vector2(128, 128)
const FRAME_START := 20
const FRAME_COUNT := 6

var velocity := Vector2.ZERO
var _elapsed := 0.0

func _ready() -> void:
	texture = COIN_SHEET
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	region_enabled = true

func launch(initial_velocity: Vector2) -> void:
	velocity = initial_velocity

func _process(delta: float) -> void:
	_elapsed += delta
	region_rect = Rect2(Vector2((FRAME_START + int(_elapsed * 12.0) % FRAME_COUNT) * FRAME_SIZE.x, 0), FRAME_SIZE)
	velocity.y += GRAVITY * delta
	global_position += velocity * delta
	rotation += velocity.x * delta * 0.004
	if is_inside_tree() and global_position.y > get_viewport_rect().end.y + 32.0:
		queue_free()
