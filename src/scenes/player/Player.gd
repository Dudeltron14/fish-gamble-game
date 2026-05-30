extends CharacterBody2D

const SPEED := 100.0

@export var player_name: String = "":
	set(v):
		player_name = v
		if is_node_ready() and name_label:
			name_label.text = v

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var name_label: Label = $NameLabel
@onready var camera: Camera2D = $Camera2D

var _is_fishing := false

func _ready() -> void:
	var is_local := multiplayer.get_unique_id() == get_multiplayer_authority()
	set_physics_process(is_local)
	camera.enabled = is_local
	name_label.text = player_name

func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	_update_animation(dir)
	move_and_slide()

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

func play_hook() -> void:
	sprite.play("hook")

func stop_fishing() -> void:
	_is_fishing = false
	var is_local := multiplayer.get_unique_id() == get_multiplayer_authority()
	set_physics_process(is_local)
	sprite.play("idle")
