extends CharacterBody2D

const SPEED := 100.0
const STATE_SEND_INTERVAL := 0.08
const REMOTE_LERP_SPEED := 12.0
const CATCH_DISPLAY_SECONDS := 2.0
const CATCH_DISPLAY_SIZE := 32.0
const FISH_SHEET := preload("res://assets/free fish/free fish.png")
const FISH_FRAME_SIZE := Vector2i(16, 16)
const FISH_SHEET_COLUMNS := 3
const JUNK_SHEET := preload("res://assets/free fish/junk.png")
const JUNK_REGIONS := {
	"junk_boot": Rect2(222, 368, 257, 238),
	"junk_can": Rect2(613, 361, 197, 245),
	"junk_seaweed": Rect2(963, 368, 219, 238),
}

@export var player_name: String = "":
	set(v):
		player_name = v
		if is_node_ready() and name_label:
			name_label.text = v

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var name_label: Label = $NameLabel
@onready var camera: Camera2D = $Camera2D
@onready var bobber_visual: Node2D = $BobberVisual
@onready var catch_sprite: Sprite2D = $CatchSprite

var _is_fishing := false
var _is_hidden_for_menu := false
var _state_send_accum := 0.0
var _remote_target_position := Vector2.ZERO
var _bobber_cast_quality := -1.0
var _catch_tween: Tween = null

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
	_bobber_cast_quality = -1.0
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
	_bobber_cast_quality = -1.0
	var is_local := _is_local_authority()
	set_physics_process(is_local)
	sprite.play("idle")
	_update_bobber(false)
	_send_state()

func set_menu_hidden(menu_hidden: bool) -> void:
	_is_hidden_for_menu = menu_hidden
	visible = not menu_hidden
	_update_bobber(_is_fishing)
	_send_state()

func set_cast_quality(cast_quality: float) -> void:
	_bobber_cast_quality = clampf(cast_quality, 0.0, 1.0)
	_update_bobber(_is_fishing)
	_send_state()

func show_catch(fish_id: String) -> void:
	var fish := ItemRegistry.get_item(fish_id) as FishData
	if fish == null:
		return
	catch_sprite.texture = _catch_texture_for(fish)
	if catch_sprite.texture == null:
		return
	var texture_size := catch_sprite.texture.get_size()
	var max_size := maxf(texture_size.x, texture_size.y)
	catch_sprite.scale = Vector2.ONE * (CATCH_DISPLAY_SIZE / max_size)
	catch_sprite.modulate = Color.WHITE
	catch_sprite.position = Vector2(8, -41)
	catch_sprite.visible = true
	if _catch_tween:
		_catch_tween.kill()
	_catch_tween = create_tween().set_parallel(true)
	_catch_tween.tween_property(catch_sprite, "position:y", -53.0, CATCH_DISPLAY_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_catch_tween.tween_property(catch_sprite, "modulate:a", 0.0, 0.35).set_delay(CATCH_DISPLAY_SECONDS - 0.35)
	_catch_tween.finished.connect(func() -> void:
		catch_sprite.visible = false
		catch_sprite.texture = null
	)

func apply_remote_state(pos: Vector2, animation: String, flip_h: bool, menu_hidden: bool, bobber_cast_quality: float = -1.0) -> void:
	_remote_target_position = pos
	visible = not menu_hidden
	if sprite.sprite_frames and sprite.animation != animation:
		sprite.play(animation)
	sprite.flip_h = flip_h
	_bobber_cast_quality = -1.0 if bobber_cast_quality < 0.0 else clampf(bobber_cast_quality, 0.0, 1.0)
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
	NetAPI.rpc_id(1, "c2s_player_state", position, str(sprite.animation), sprite.flip_h, _is_hidden_for_menu, _bobber_cast_quality)

func _is_local_authority() -> bool:
	return multiplayer.get_unique_id() == get_multiplayer_authority()

func _update_bobber(force_visible: bool) -> void:
	if bobber_visual and bobber_visual.has_method("set_cast_visible"):
		var show_bobber := force_visible and not _is_hidden_for_menu and _bobber_cast_quality >= 0.0
		bobber_visual.set_cast_visible(show_bobber, sprite.flip_h, maxf(_bobber_cast_quality, 0.0))

func _catch_texture_for(fish: FishData) -> Texture2D:
	if fish.icon:
		return fish.icon
	if fish.sprite_frame < 0:
		return null
	var atlas := AtlasTexture.new()
	if JUNK_REGIONS.has(fish.id):
		atlas.atlas = JUNK_SHEET
		atlas.region = JUNK_REGIONS[fish.id]
	else:
		var frame := maxi(fish.sprite_frame, 0)
		var column := frame % FISH_SHEET_COLUMNS
		var row := floori(float(frame) / float(FISH_SHEET_COLUMNS))
		atlas.atlas = FISH_SHEET
		atlas.region = Rect2(
			Vector2(column * FISH_FRAME_SIZE.x, row * FISH_FRAME_SIZE.y),
			FISH_FRAME_SIZE
		)
	return atlas
