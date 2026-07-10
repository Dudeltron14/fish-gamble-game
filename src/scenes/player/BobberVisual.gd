extends Node2D

const OUTLINE := Color(0.10, 0.10, 0.18, 1.0)
const RED := Color(0.86, 0.18, 0.14, 1.0)
const WHITE := Color(0.94, 0.92, 0.82, 1.0)
const WATER_RING := Color(0.30, 0.62, 0.82, 0.75)
const SPLASH_SHEET := preload("res://assets/User_Gen_ChatGPT/bobber_splash_sheet.png")
const SPLASH_FRAME_SIZE := Vector2(32, 32)
const SPLASH_FRAMES := 8
const SPLASH_FRAME_TIME := 0.07

@export var close_offset := Vector2(34, 18)
@export var far_offset := Vector2(172, 60)

var _flip_h := false
var _cast_quality := 0.0
var _time := 0.0
var _splash_time := 0.0
var _splash_active := false

func _ready() -> void:
	visible = false
	set_process(false)
	z_index = 8

func set_cast_visible(show: bool, flip_h: bool, cast_quality: float) -> void:
	var was_visible := visible
	_flip_h = flip_h
	_cast_quality = clampf(cast_quality, 0.0, 1.0)
	visible = show
	set_process(show)
	if show:
		if not was_visible:
			_time = 0.0
			_splash_time = 0.0
			_splash_active = true
			AudioManager.sfx("sfx_bobber_splash")
	else:
		_splash_active = false
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if _splash_active:
		_splash_time += delta
		if _splash_time >= SPLASH_FRAMES * SPLASH_FRAME_TIME:
			_splash_active = false
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var dir := -1.0 if _flip_h else 1.0
	var cast_offset := close_offset.lerp(far_offset, _cast_quality)
	var bob := Vector2(cast_offset.x * dir, cast_offset.y + sin(_time * 5.5) * 2.0)
	_draw_splash(bob)
	draw_arc(bob + Vector2(0, 2), 7.0, 0.0, TAU, 28, WATER_RING, 1.0)
	draw_rect(Rect2(bob + Vector2(-3, -6), Vector2(6, 10)), OUTLINE)
	draw_rect(Rect2(bob + Vector2(-2, -5), Vector2(4, 4)), RED)
	draw_rect(Rect2(bob + Vector2(-2, -1), Vector2(4, 4)), WHITE)

func _draw_splash(center: Vector2) -> void:
	if not _splash_active:
		return
	var frame := mini(int(_splash_time / SPLASH_FRAME_TIME), SPLASH_FRAMES - 1)
	var region := Rect2(Vector2(frame * SPLASH_FRAME_SIZE.x, 0), SPLASH_FRAME_SIZE)
	var dest := Rect2(center - SPLASH_FRAME_SIZE * 0.5 + Vector2(0, 2), SPLASH_FRAME_SIZE)
	draw_texture_rect_region(SPLASH_SHEET, dest, region)
