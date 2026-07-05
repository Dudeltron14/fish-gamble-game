extends Node2D

const OUTLINE := Color(0.10, 0.10, 0.18, 1.0)
const RED := Color(0.86, 0.18, 0.14, 1.0)
const WHITE := Color(0.94, 0.92, 0.82, 1.0)
const WATER_RING := Color(0.30, 0.62, 0.82, 0.75)

@export var close_offset := Vector2(34, 18)
@export var far_offset := Vector2(172, 60)

var _flip_h := false
var _cast_quality := 0.0
var _time := 0.0

func _ready() -> void:
	visible = false
	set_process(false)
	z_index = 8

func set_cast_visible(show: bool, flip_h: bool, cast_quality: float) -> void:
	_flip_h = flip_h
	_cast_quality = clampf(cast_quality, 0.0, 1.0)
	visible = show
	set_process(show)
	if show:
		_time = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var dir := -1.0 if _flip_h else 1.0
	var cast_offset := close_offset.lerp(far_offset, _cast_quality)
	var bob := Vector2(cast_offset.x * dir, cast_offset.y + sin(_time * 5.5) * 2.0)
	draw_arc(bob + Vector2(0, 2), 7.0, 0.0, TAU, 28, WATER_RING, 1.0)
	draw_rect(Rect2(bob + Vector2(-3, -6), Vector2(6, 10)), OUTLINE)
	draw_rect(Rect2(bob + Vector2(-2, -5), Vector2(4, 4)), RED)
	draw_rect(Rect2(bob + Vector2(-2, -1), Vector2(4, 4)), WHITE)
