extends Sprite2D

const KEY_SHADER := preload("res://src/shaders/menu_effect_key.gdshader")

@export var frame_count := 16:
	set(value):
		frame_count = max(1, value)
		_update_region()

@export var fps := 10.0
@export var animate_frames := true:
	set(value):
		animate_frames = value
		_update_region()

@export var use_frame_region := true:
	set(value):
		use_frame_region = value
		_update_region()

@export var start_frame := 0:
	set(value):
		start_frame = max(0, value)
		_update_region()

@export var pulse_scale_amount := 0.0
@export var pulse_alpha_amount := 0.0
@export var pulse_speed := 1.0

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
var _base_scale := Vector2.ONE
var _last_applied_scale := Vector2.ONE

func _ready() -> void:
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modulate.a = alpha
	_base_scale = scale
	_last_applied_scale = scale
	_update_material()
	_update_region()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_update_region()
	_update_pulse()

func _update_region() -> void:
	if texture == null:
		return
	region_enabled = use_frame_region
	if not use_frame_region:
		return
	var frame_width := float(texture.get_width()) / float(frame_count)
	var frame_height := float(texture.get_height())
	var frame := start_frame % frame_count
	if animate_frames:
		frame = (int(floor(_time * fps)) + start_frame) % frame_count
	region_rect = Rect2(Vector2(frame_width * frame, 0.0), Vector2(frame_width, frame_height))

func _update_pulse() -> void:
	if scale != _last_applied_scale:
		_base_scale = scale
	var pulse := 0.5 + 0.5 * sin(_time * pulse_speed)
	scale = _base_scale * (1.0 + pulse_scale_amount * pulse)
	_last_applied_scale = scale
	modulate.a = clampf(alpha + pulse_alpha_amount * pulse, 0.0, 1.0)

func _update_material() -> void:
	if remove_generated_background:
		var shader_material := ShaderMaterial.new()
		shader_material.shader = KEY_SHADER
		shader_material.set_shader_parameter("alpha_multiplier", alpha)
		material = shader_material
	else:
		material = null
