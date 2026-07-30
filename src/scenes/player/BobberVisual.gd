extends Node2D

const OUTLINE := Color(0.10, 0.10, 0.18, 1.0)
const RED := Color(0.86, 0.18, 0.14, 1.0)
const WHITE := Color(0.94, 0.92, 0.82, 1.0)
const WATER_RING := Color(0.30, 0.62, 0.82, 0.75)
const SPLASH_SHEET := preload("res://assets/User_Gen_ChatGPT/bobber_splash_sheet.png")
const SPLASH_FRAME_SIZE := Vector2(32, 32)
const SPLASH_FRAMES := 8
const SPLASH_FRAME_TIME := 0.07
const CAST_GRAVITY := 730.0
const CAST_ARC_HEIGHT := Vector2(15.68, 51.52)
const LINE_SEGMENTS := 16
const LINE_SETTLE_SECONDS := 0.45
const LINE_COLOR := Color(0.20, 0.16, 0.10, 0.9)
const LINE_OUTLINE := Color(0.05, 0.04, 0.03, 0.8)

@export var close_offset := Vector2(34, 18)
@export var far_offset := Vector2(172, 60)

var _flip_h := false
var _cast_quality := 0.0
var _time := 0.0
var _splash_time := 0.0
var _splash_active := false
var _is_casting := false
var _bobber_position := Vector2.ZERO
var _bobber_velocity := Vector2.ZERO
var _cast_target := Vector2.ZERO
var _line_settle := 1.0
var _skin_texture: Texture2D
var _line_origin := Vector2(16, -15)

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
		if not was_visible and not _is_casting:
			_land()
	else:
		_is_casting = false
		_splash_active = false
	queue_redraw()

func play_cast(flip_h: bool, cast_quality: float) -> void:
	if _is_casting:
		return
	_flip_h = flip_h
	_cast_quality = clampf(cast_quality, 0.0, 1.0)
	visible = true
	set_process(true)
	_is_casting = true
	_bobber_position = _rod_tip()
	_cast_target = _resting_position()
	var upward_speed: float = -sqrt(2.0 * CAST_GRAVITY * lerpf(CAST_ARC_HEIGHT.x, CAST_ARC_HEIGHT.y, _cast_quality))
	var vertical_distance: float = _cast_target.y - _bobber_position.y
	var flight_time: float = (-upward_speed + sqrt(maxf(0.0, upward_speed * upward_speed + 2.0 * CAST_GRAVITY * vertical_distance))) / CAST_GRAVITY
	_bobber_velocity = Vector2((_cast_target.x - _bobber_position.x) / maxf(flight_time, 0.1), upward_speed)
	_line_settle = 0.0
	_splash_active = false
	queue_redraw()

func set_skin(bobber_id: String) -> void:
	var item := CosmeticCatalog.get_item(bobber_id)
	_skin_texture = item.get("icon") as Texture2D
	queue_redraw()

func set_line_origin(origin: Vector2) -> void:
	if _line_origin == origin:
		return
	_line_origin = origin
	queue_redraw()

func _process(delta: float) -> void:
	if _is_casting:
		_bobber_velocity.y += CAST_GRAVITY * delta
		_bobber_position += _bobber_velocity * delta
		if _bobber_velocity.y > 0.0 and _bobber_position.y >= _cast_target.y:
			_bobber_position = _cast_target
			_land()
	else:
		_time += delta
		_line_settle = minf(1.0, _line_settle + delta / LINE_SETTLE_SECONDS)
	if _splash_active:
		_splash_time += delta
		if _splash_time >= SPLASH_FRAMES * SPLASH_FRAME_TIME:
			_splash_active = false
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var bob := _bobber_position if _is_casting else _resting_position() + Vector2(0, sin(_time * 5.5) * 2.0)
	_draw_line(_rod_tip(), bob)
	_draw_splash(bob)
	draw_arc(bob + Vector2(0, 2), 7.0, 0.0, TAU, 28, WATER_RING, 1.0)
	if _skin_texture:
		draw_texture(_skin_texture, bob - Vector2(8, 8))
	else:
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

func _draw_line(start: Vector2, finish: Vector2) -> void:
	var slack := 0.5 if _is_casting else lerpf(0.5, 8.0, ease(_line_settle, 2.0))
	var control := start.lerp(finish, 0.5) + Vector2(0, slack)
	var previous := start
	for step in range(1, LINE_SEGMENTS + 1):
		var point := _quadratic_bezier(start, control, finish, float(step) / LINE_SEGMENTS)
		draw_line(previous, point, LINE_OUTLINE, 2.0, true)
		draw_line(previous, point, LINE_COLOR, 1.0, true)
		previous = point

func _quadratic_bezier(start: Vector2, control: Vector2, finish: Vector2, t: float) -> Vector2:
	return start.lerp(control, t).lerp(control.lerp(finish, t), t)

func _rod_tip() -> Vector2:
	return _line_origin

func _resting_position() -> Vector2:
	var direction := -1.0 if _flip_h else 1.0
	var cast_offset := close_offset.lerp(far_offset, _cast_quality)
	return Vector2(cast_offset.x * direction, cast_offset.y)

func _land() -> void:
	_is_casting = false
	_time = 0.0
	_line_settle = 0.0
	_splash_time = 0.0
	_splash_active = true
	AudioManager.sfx("sfx_bobber_splash")
