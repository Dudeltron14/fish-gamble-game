extends CharacterBody2D

const SPEED := 100.0

@export var player_name: String = "":
	set(v):
		player_name = v
		if is_node_ready() and name_label:
			name_label.text = v

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var name_label: Label = $NameLabel

func _ready() -> void:
	var is_local := multiplayer.get_unique_id() == get_multiplayer_authority()
	set_physics_process(is_local)
	name_label.text = player_name

func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * SPEED
	_update_animation(dir)
	move_and_slide()

func _update_animation(dir: Vector2) -> void:
	if not sprite.sprite_frames:
		return
	if dir == Vector2.ZERO:
		sprite.play("idle")
	else:
		sprite.flip_h = dir.x < 0
		sprite.play("walk_right")
