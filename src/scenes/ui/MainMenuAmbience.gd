extends Control

const FRAME_COUNT := 16

const FLAME_SHEET := "res://assets/User_Gen_ChatGPT/Main Menu/Menu_effects/small_lantern_flame_flicker.png"
const GLOW_SHEET := "res://assets/User_Gen_ChatGPT/Main Menu/Menu_effects/Soft_warm_glow.png"
const WATER_SHEET := "res://assets/User_Gen_ChatGPT/Main Menu/Menu_effects/subtle_water_shimmer.png"
const SPARKLE_SHEET := "res://assets/User_Gen_ChatGPT/Main Menu/Menu_effects/tiny_golden_coin_sparkle.png"
const DUST_SHEET := "res://assets/User_Gen_ChatGPT/Main Menu/Menu_effects/tiny_warm_dust.png"

const KEY_SHADER := preload("res://src/shaders/menu_effect_key.gdshader")

const EFFECTS := [
	# Lanterns and lamp glows.
	{"sheet": FLAME_SHEET, "pos": Vector2(0.255, 0.146), "size": 30.0, "fps": 10.0, "start": 0, "key": true, "alpha": 0.95},
	{"sheet": FLAME_SHEET, "pos": Vector2(0.431, 0.125), "size": 24.0, "fps": 9.0, "start": 5, "key": true, "alpha": 0.78},
	{"sheet": FLAME_SHEET, "pos": Vector2(0.770, 0.147), "size": 24.0, "fps": 9.5, "start": 9, "key": true, "alpha": 0.78},
	{"sheet": FLAME_SHEET, "pos": Vector2(0.047, 0.619), "size": 30.0, "fps": 10.0, "start": 3, "key": true, "alpha": 0.86},
	{"sheet": FLAME_SHEET, "pos": Vector2(0.306, 0.908), "size": 24.0, "fps": 9.0, "start": 11, "key": true, "alpha": 0.72},
	{"sheet": FLAME_SHEET, "pos": Vector2(0.741, 0.840), "size": 22.0, "fps": 8.5, "start": 7, "key": true, "alpha": 0.65},
	{"sheet": FLAME_SHEET, "pos": Vector2(0.926, 0.395), "size": 28.0, "fps": 10.0, "start": 13, "key": true, "alpha": 0.82},

	{"sheet": GLOW_SHEET, "pos": Vector2(0.305, 0.228), "size": 116.0, "fps": 7.5, "start": 2, "key": false, "alpha": 0.55},
	{"sheet": GLOW_SHEET, "pos": Vector2(0.699, 0.229), "size": 106.0, "fps": 7.0, "start": 7, "key": false, "alpha": 0.48},
	{"sheet": GLOW_SHEET, "pos": Vector2(0.165, 0.519), "size": 118.0, "fps": 7.5, "start": 11, "key": false, "alpha": 0.44},
	{"sheet": GLOW_SHEET, "pos": Vector2(0.825, 0.513), "size": 96.0, "fps": 7.0, "start": 5, "key": false, "alpha": 0.36},

	# Aquarium and harbor water shimmer.
	{"sheet": WATER_SHEET, "pos": Vector2(0.136, 0.320), "size": 132.0, "fps": 8.0, "start": 1, "key": true, "alpha": 0.58},
	{"sheet": WATER_SHEET, "pos": Vector2(0.784, 0.265), "size": 78.0, "fps": 7.0, "start": 8, "key": true, "alpha": 0.44},

	# Coins and shiny props. Each start is staggered so repeats do not sync.
	{"sheet": SPARKLE_SHEET, "pos": Vector2(0.789, 0.515), "size": 28.0, "fps": 11.0, "start": 0, "key": true, "alpha": 0.86},
	{"sheet": SPARKLE_SHEET, "pos": Vector2(0.829, 0.431), "size": 24.0, "fps": 10.0, "start": 4, "key": true, "alpha": 0.72},
	{"sheet": SPARKLE_SHEET, "pos": Vector2(0.862, 0.501), "size": 24.0, "fps": 10.5, "start": 8, "key": true, "alpha": 0.78},
	{"sheet": SPARKLE_SHEET, "pos": Vector2(0.876, 0.776), "size": 30.0, "fps": 11.5, "start": 12, "key": true, "alpha": 0.9},
	{"sheet": SPARKLE_SHEET, "pos": Vector2(0.744, 0.602), "size": 20.0, "fps": 9.5, "start": 6, "key": true, "alpha": 0.58},
	{"sheet": SPARKLE_SHEET, "pos": Vector2(0.244, 0.585), "size": 18.0, "fps": 9.5, "start": 2, "key": true, "alpha": 0.48},
	{"sheet": SPARKLE_SHEET, "pos": Vector2(0.151, 0.887), "size": 18.0, "fps": 9.0, "start": 10, "key": true, "alpha": 0.52},
	{"sheet": SPARKLE_SHEET, "pos": Vector2(0.951, 0.075), "size": 20.0, "fps": 10.0, "start": 14, "key": true, "alpha": 0.62},

	# Dust motes in light shafts. Kept sparse and staggered.
	{"sheet": DUST_SHEET, "pos": Vector2(0.207, 0.590), "size": 44.0, "fps": 6.0, "start": 0, "key": true, "alpha": 0.38},
	{"sheet": DUST_SHEET, "pos": Vector2(0.251, 0.897), "size": 42.0, "fps": 5.5, "start": 5, "key": true, "alpha": 0.34},
	{"sheet": DUST_SHEET, "pos": Vector2(0.772, 0.602), "size": 40.0, "fps": 6.5, "start": 10, "key": true, "alpha": 0.32},
	{"sheet": DUST_SHEET, "pos": Vector2(0.880, 0.448), "size": 38.0, "fps": 5.5, "start": 13, "key": true, "alpha": 0.30},
]

var _time := 0.0
var _effect_nodes: Array[Sprite2D] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_effects()

func _process(delta: float) -> void:
	_time += delta
	_update_effects()
	queue_redraw()

func _draw() -> void:
	var flicker := 0.018 + 0.012 * sin(_time * 1.7) + 0.007 * sin(_time * 4.1)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.58, 0.18, flicker), false, 1.0)

func _create_effects() -> void:
	for effect in EFFECTS:
		var texture := load(effect["sheet"]) as Texture2D
		if texture == null:
			push_warning("MainMenuAmbience: missing effect sheet %s" % effect["sheet"])
			continue
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.region_enabled = true
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.modulate.a = float(effect.get("alpha", 1.0))
		if bool(effect.get("key", false)):
			var material := ShaderMaterial.new()
			material.shader = KEY_SHADER
			material.set_shader_parameter("alpha_multiplier", float(effect.get("alpha", 1.0)))
			sprite.material = material
		sprite.set_meta("effect", effect)
		add_child(sprite)
		_effect_nodes.append(sprite)
	_update_effects()

func _update_effects() -> void:
	for sprite in _effect_nodes:
		if not is_instance_valid(sprite):
			continue
		var effect: Dictionary = sprite.get_meta("effect")
		var texture := sprite.texture
		if texture == null:
			continue
		var frame_width := float(texture.get_width()) / float(FRAME_COUNT)
		var frame_height := float(texture.get_height())
		var frame := (int(floor(_time * float(effect.get("fps", 8.0)))) + int(effect.get("start", 0))) % FRAME_COUNT
		sprite.region_rect = Rect2(Vector2(frame_width * frame, 0.0), Vector2(frame_width, frame_height))
		sprite.position = effect["pos"] * size
		var target_size := float(effect.get("size", 32.0))
		var longest_side := maxf(frame_width, frame_height)
		sprite.scale = Vector2.ONE * (target_size / longest_side)
