extends CharacterBody2D

const SPEED := 100.0
const STATE_SEND_INTERVAL := 0.08
const REMOTE_LERP_SPEED := 12.0

@export var player_name: String = "":
	set(v):
		player_name = v
		if is_node_ready() and name_label:
			name_label.text = v

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var name_label: Label = $NameLabel
@onready var camera: Camera2D = $Camera2D
@onready var bobber_visual: Node2D = $BobberVisual

var _is_fishing := false
var _is_hidden_for_menu := false
var _state_send_accum := 0.0
var _remote_target_position := Vector2.ZERO

func _ready() -> void:
	_update_local_control()
	name_label.text = player_name
	_remote_target_position = position
	if not _is_local_authority():
		set_process(true)

func _enter_tree() -> void:
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())
	call_deferred("_update_local_control")

func _update_local_control() -> void:
	if not is_node_ready():
		return
	var is_local := _is_local_authority()
	set_physics_process(is_local)
	camera.enabled = is_local

func _process(delta: float) -> void:
	if _is_local_authority():
		return
	position = position.lerp(_remote_target_position, minf(1.0, REMOTE_LERP_SPEED * delta))

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	_update_animation(dir)
	move_and_slide()
	_send_state_if_due(delta)

func _update_animation(dir: Vector2) -> void:
	if _is_fishing:
		return
	if not sprite.sprite_frames:
		return
	if dir == Vector2.ZERO:
		sprite.play("idle")
	else:
		sprite.flip_h = dir.x < 0
		sprite.play("walk_right")

func start_fishing() -> void:
	_is_fishing = true
	set_physics_process(false)
	velocity = Vector2.ZERO
	sprite.play("fishing")
	_update_bobber(true)
	_send_state()

func play_hook() -> void:
	sprite.play("hook")
	_update_bobber(false)
	_send_state()

func stop_fishing() -> void:
	_is_fishing = false
	var is_local := _is_local_authority()
	set_physics_process(is_local)
	sprite.play("idle")
	_update_bobber(false)
	_send_state()

func set_menu_hidden(hidden: bool) -> void:
	_is_hidden_for_menu = hidden
	visible = not hidden
	_update_bobber(_is_fishing)
	_send_state()

func apply_remote_state(pos: Vector2, animation: String, flip_h: bool, hidden: bool) -> void:
	_remote_target_position = pos
	visible = not hidden
	if sprite.sprite_frames and sprite.animation != animation:
		sprite.play(animation)
	sprite.flip_h = flip_h
	_update_bobber(animation == "fishing")

func _send_state_if_due(delta: float) -> void:
	_state_send_accum += delta
	if _state_send_accum < STATE_SEND_INTERVAL:
		return
	_state_send_accum = 0.0
	_send_state()

func _send_state() -> void:
	if not _is_local_authority() or multiplayer.multiplayer_peer == null:
		return
	NetAPI.rpc_id(1, "c2s_player_state", position, str(sprite.animation), sprite.flip_h, _is_hidden_for_menu)

func _is_local_authority() -> bool:
	return multiplayer.get_unique_id() == get_multiplayer_authority()

func _update_bobber(force_visible: bool) -> void:
	if bobber_visual and bobber_visual.has_method("set_cast_visible"):
		bobber_visual.set_cast_visible(force_visible and not _is_hidden_for_menu, sprite.flip_h)
