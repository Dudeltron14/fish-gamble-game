extends Control

class DustMote:
	var pos: Vector2
	var speed: float
	var radius: float
	var phase: float

class Sparkle:
	var pos: Vector2
	var phase: float
	var size: float

const LANTERNS := [
	Vector2(0.305, 0.23),
	Vector2(0.695, 0.23),
	Vector2(0.165, 0.52),
	Vector2(0.835, 0.52),
]

const COIN_PILES := [
	Vector2(0.23, 0.58),
	Vector2(0.77, 0.58),
	Vector2(0.17, 0.42),
	Vector2(0.83, 0.42),
]

var _time := 0.0
var _dust: Array[DustMote] = []
var _sparkles: Array[Sparkle] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_particles()

func _process(delta: float) -> void:
	_time += delta
	for mote in _dust:
		mote.pos.y -= mote.speed * delta
		mote.pos.x += sin(_time * 0.45 + mote.phase) * delta * 5.0
		if mote.pos.y < -0.05:
			mote.pos.y = 1.05
	queue_redraw()

func _draw() -> void:
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	_draw_lantern_glow(viewport_size)
	_draw_water_shimmer(viewport_size)
	_draw_dust(viewport_size)
	_draw_coin_sparkles(viewport_size)
	_draw_light_flicker(viewport_size)

func _build_particles() -> void:
	_dust.clear()
	_sparkles.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 13077
	for i in 46:
		var mote := DustMote.new()
		mote.pos = Vector2(rng.randf(), rng.randf())
		mote.speed = rng.randf_range(0.008, 0.023)
		mote.radius = rng.randf_range(0.8, 1.8)
		mote.phase = rng.randf_range(0.0, TAU)
		_dust.append(mote)
	for pile in COIN_PILES:
		for i in 5:
			var sparkle := Sparkle.new()
			sparkle.pos = pile + Vector2(rng.randf_range(-0.035, 0.035), rng.randf_range(-0.025, 0.025))
			sparkle.phase = rng.randf_range(0.0, TAU)
			sparkle.size = rng.randf_range(3.0, 6.0)
			_sparkles.append(sparkle)

func _draw_lantern_glow(viewport_size: Vector2) -> void:
	for i in LANTERNS.size():
		var center: Vector2 = LANTERNS[i] * viewport_size
		var pulse := 0.5 + 0.5 * sin(_time * 2.4 + float(i) * 0.9)
		var radius := viewport_size.y * (0.052 + pulse * 0.009)
		_draw_soft_circle(center, radius, Color(1.0, 0.58, 0.12, 0.12 + pulse * 0.07), 6)
		_draw_soft_circle(center, radius * 0.42, Color(1.0, 0.78, 0.30, 0.18 + pulse * 0.08), 4)

func _draw_dust(viewport_size: Vector2) -> void:
	for mote in _dust:
		var alpha := 0.08 + 0.08 * sin(_time * 0.8 + mote.phase)
		draw_circle(mote.pos * viewport_size, mote.radius, Color(1.0, 0.78, 0.42, alpha))

func _draw_coin_sparkles(viewport_size: Vector2) -> void:
	for sparkle in _sparkles:
		var twinkle := maxf(0.0, sin(_time * 4.2 + sparkle.phase))
		if twinkle < 0.28:
			continue
		var center: Vector2 = sparkle.pos * viewport_size
		var arm := sparkle.size * (0.7 + twinkle * 0.7)
		var color := Color(1.0, 0.82, 0.28, 0.18 + twinkle * 0.42)
		draw_line(center + Vector2(-arm, 0.0), center + Vector2(arm, 0.0), color, 1.4)
		draw_line(center + Vector2(0.0, -arm), center + Vector2(0.0, arm), color, 1.4)
		draw_circle(center, 1.3, Color(1.0, 0.94, 0.58, 0.5 * twinkle))

func _draw_water_shimmer(viewport_size: Vector2) -> void:
	var y_base := viewport_size.y * 0.74
	for i in 8:
		var y := y_base + float(i) * viewport_size.y * 0.018
		var offset := sin(_time * 0.8 + float(i) * 0.65) * viewport_size.x * 0.018
		var alpha := 0.018 + 0.02 * sin(_time * 1.3 + float(i))
		var start := Vector2(viewport_size.x * 0.28 + offset, y)
		var end := Vector2(viewport_size.x * 0.72 + offset, y + sin(_time + float(i)) * 2.0)
		draw_line(start, end, Color(0.55, 0.95, 0.82, alpha), 1.0)

func _draw_light_flicker(viewport_size: Vector2) -> void:
	var flicker := 0.035 + 0.025 * sin(_time * 1.7) + 0.015 * sin(_time * 4.1)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(1.0, 0.62, 0.24, flicker), false, 1.0)

func _draw_soft_circle(center: Vector2, radius: float, color: Color, steps: int) -> void:
	for i in steps:
		var t := 1.0 - float(i) / float(steps)
		var c := color
		c.a *= t * t
		draw_circle(center, radius * t, c)
