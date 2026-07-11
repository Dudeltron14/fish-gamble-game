@tool
extends Sprite2D

const KEY_SHADER := preload("res://src/shaders/menu_effect_key.gdshader")

@export var frame_count := 16:
	set(value):
		frame_count = max(1, value)
		_update_region()

@export var fps := 10.0
@export var start_frame := 0:
	set(value):
		start_frame = max(0, value)
		_update_region()

@export var alpha := 1.0:
	set(value):
		alpha = clampf(value, 0.0, 1.0)
		modulate.a = alpha
		_update_material()

@export var remove_generated_background := true:
	set(value):
		remove_generated_background = value
		_update_material()

var _time := 0.0

func _ready() -> void:
	centered = true
	region_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modulate.a = alpha
	_update_material()
	_update_region()

func _process(delta: float) -> void:
	_time += delta
	_update_region()

func _update_region() -> void:
	if texture == null:
		return
	var frame_width := float(texture.get_width()) / float(frame_count)
	var frame_height := float(texture.get_height())
	var frame := (int(floor(_time * fps)) + start_frame) % frame_count
	region_rect = Rect2(Vector2(frame_width * frame, 0.0), Vector2(frame_width, frame_height))

func _update_material() -> void:
	if remove_generated_background:
		var shader_material := ShaderMaterial.new()
		shader_material.shader = KEY_SHADER
		shader_material.set_shader_parameter("alpha_multiplier", alpha)
		material = shader_material
	else:
		material = null
