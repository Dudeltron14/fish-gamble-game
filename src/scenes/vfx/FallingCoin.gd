extends Sprite2D

const GRAVITY := 1400.0

var velocity := Vector2.ZERO

func launch(initial_velocity: Vector2) -> void:
	velocity = initial_velocity

func _process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	global_position += velocity * delta
	rotation += velocity.x * delta * 0.004
	if is_inside_tree() and global_position.y > get_viewport_rect().end.y + 32.0:
		queue_free()
