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

const LANTERN_GLOWS := [
	{"pos": Vector2(0.305, 0.228), "radius": 0.058, "strength": 0.95},
	{"pos": Vector2(0.431, 0.125), "radius": 0.038, "strength": 0.62},
	{"pos": Vector2(0.699, 0.229), "radius": 0.056, "strength": 0.86},
	{"pos": Vector2(0.165, 0.519), "radius": 0.064, "strength": 0.82},
	{"pos": Vector2(0.047, 0.628), "radius": 0.040, "strength": 0.58},
	{"pos": Vector2(0.306, 0.913), "radius": 0.038, "strength": 0.50},
	{"pos": Vector2(0.841, 0.884), "radius": 0.037, "strength": 0.48},
]

const SPARKLE_CLUSTERS := [
	Vector2(0.789, 0.515),
	Vector2(0.829, 0.431),
	Vector2(0.862, 0.501),
	Vector2(0.876, 0.776),
	Vector2(0.744, 0.602),
	Vector2(0.244, 0.585),
	Vector2(0.151, 0.887),
	Vector2(0.951, 0.075),
]

const WATER_REGIONS := [
	Rect2(0.060, 0.248, 0.150, 0.142),
	Rect2(0.747, 0.170, 0.075, 0.190),
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
	for cluster in SPARKLE_CLUSTERS:
		for i in 4:
			var sparkle := Sparkle.new()
			sparkle.pos = cluster + Vector2(rng.randf_range(-0.024, 0.024), rng.randf_range(-0.018, 0.018))
			sparkle.phase = rng.randf_range(0.0, TAU)
			sparkle.size = rng.randf_range(3.0, 6.0)
			_sparkles.append(sparkle)

func _draw_lantern_glow(viewport_size: Vector2) -> void:
	for i in LANTERN_GLOWS.size():
		var glow: Dictionary = LANTERN_GLOWS[i]
		var center: Vector2 = glow["pos"] * viewport_size
		var pulse := 0.5 + 0.5 * sin(_time * 2.4 + float(i) * 0.9)
		var strength: float = glow["strength"]
		var radius := viewport_size.y * (float(glow["radius"]) + pulse * 0.006)
		_draw_soft_circle(center, radius, Color(1.0, 0.58, 0.12, (0.08 + pulse * 0.055) * strength), 6)
		_draw_soft_circle(center, radius * 0.42, Color(1.0, 0.78, 0.30, (0.12 + pulse * 0.06) * strength), 4)

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
	for region in WATER_REGIONS:
		var rect := Rect2(region.position * viewport_size, region.size * viewport_size)
		for i in 5:
			var y := rect.position.y + rect.size.y * (0.28 + float(i) * 0.13)
			var offset := sin(_time * 0.9 + float(i) * 0.65) * rect.size.x * 0.07
			var alpha := 0.025 + 0.025 * sin(_time * 1.4 + float(i))
			var start := Vector2(rect.position.x + rect.size.x * 0.14 + offset, y)
			var end := Vector2(rect.position.x + rect.size.x * 0.86 + offset, y + sin(_time + float(i)) * 1.3)
			draw_line(start, end, Color(0.48, 0.88, 0.86, alpha), 1.0)

func _draw_light_flicker(viewport_size: Vector2) -> void:
	var flicker := 0.035 + 0.025 * sin(_time * 1.7) + 0.015 * sin(_time * 4.1)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(1.0, 0.62, 0.24, flicker), false, 1.0)

func _draw_soft_circle(center: Vector2, radius: float, color: Color, steps: int) -> void:
	for i in steps:
		var t := 1.0 - float(i) / float(steps)
		var c := color
		c.a *= t * t
		draw_circle(center, radius * t, c)
