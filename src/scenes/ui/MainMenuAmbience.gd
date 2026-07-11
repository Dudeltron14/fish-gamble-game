extends Control

var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var flicker := 0.018 + 0.012 * sin(_time * 1.7) + 0.007 * sin(_time * 4.1)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.58, 0.18, flicker), false, 1.0)
