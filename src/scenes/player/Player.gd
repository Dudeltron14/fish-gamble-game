extends CharacterBody2D

const SPEED := 100.0
const STATE_SEND_INTERVAL := 1.0 / 30.0
const REMOTE_LERP_SPEED := 18.0
const CATCH_DISPLAY_SECONDS := 2.0
const CATCH_DISPLAY_SIZE := 32.0
const FISH_SHEET := preload("res://assets/free fish/free fish.png")
const FISH_FRAME_SIZE := Vector2i(16, 16)
const FISH_SHEET_COLUMNS := 3
const CATCH_IMPACT_BLUE := preload("res://assets/vfx/catch_impact_blue_sheet.png")
const CATCH_SPARKLE_BLUE := preload("res://assets/vfx/catch_sparkle_blue_sheet.png")
const CATCH_IMPACT_GOLD := preload("res://assets/vfx/catch_impact_gold_sheet.png")
const PLAYER_RENDER_LAYER := 1000
const SPRITE_RIGHT_POSITION := Vector2(8, -2)
const SPRITE_LEFT_POSITION := Vector2(-10, -2)
const CHAT_BUBBLE_MIN_WIDTH := 65.0
const CHAT_BUBBLE_PADDING := 14.0
const CHAT_BUBBLE_HEIGHT := 18.0
const CHAT_BUBBLE_BASELINE := -42.0
const CHAT_BUBBLE_GAP := 3.0
const CHAT_BUBBLE_LIFETIME := 15.0
const ROD_TIP_TEXTURE_POINTS := {
	"fishing": [Vector2(42, 26), Vector2(42, 26), Vector2(41, 27), Vector2(41, 26)],
	"hook": [Vector2(42, 26), Vector2(33, 21), Vector2(33, 19), Vector2(31, 13), Vector2(26, 6), Vector2(24, 5)],
}
const SKIN_SHEETS := {
	"skin_deep_sea_diver": {"fishing": preload("res://assets/skins/deep_sea_diver/DS_Diver_fish_clean.png"), "idle": preload("res://assets/skins/deep_sea_diver/DS_Diver_idle.png"), "hook": preload("res://assets/skins/deep_sea_diver/DS_Diver_hook.png"), "walk_right": preload("res://assets/skins/deep_sea_diver/DS_Diver_walk.png")},
	"skin_high_roller": {"fishing": preload("res://assets/skins/high_roller/High_Roller_fish_clean.png"), "idle": preload("res://assets/skins/high_roller/High_Roller_idle.png"), "hook": preload("res://assets/skins/high_roller/High_Roller_hook.png"), "walk_right": preload("res://assets/skins/high_roller/High_Roller_walk.png")},
}

@export var player_name: String = "":
	set(v):
		player_name = v
		if is_node_ready() and name_label:
			name_label.text = v

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var name_label: Label = $NameLabel
@onready var chat_bubble: Label = $ChatBubble
@onready var chat_tail: Polygon2D = $ChatTail
@onready var chat_tail_inner: Polygon2D = $ChatTailInner
@onready var camera: Camera2D = $Camera2D
@onready var bobber_visual: Node2D = $BobberVisual
@onready var catch_sprite: Sprite2D = $CatchSprite

var _is_fishing := false
var _is_hidden_for_menu := false
var _movement_locked := false
var _state_send_accum := 0.0
var _server_state_send_accum := 0.0
var _last_input_dir := Vector2.ZERO
var _server_input_dir := Vector2.ZERO
var _remote_target_position := Vector2.ZERO
var _bobber_cast_quality := -1.0
var _catch_tween: Tween = null
var _recoil_tween: Tween = null
var _chat_messages: Array[Label] = []
var _base_sprite_frames: SpriteFrames
var _skin_id := ""

func _ready() -> void:
	_base_sprite_frames = sprite.sprite_frames
	_update_local_control()
	_update_draw_order()
	if not GameManager.camera_zoom_changed.is_connected(_on_camera_zoom_changed):
		GameManager.camera_zoom_changed.connect(_on_camera_zoom_changed)
	name_label.text = player_name
	_remote_target_position = position
	if not _is_local_authority():
		set_process(true)
	else:
		apply_cosmetics(GameManager.equipped_skin_id, GameManager.equipped_bobber_id)

func _enter_tree() -> void:
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())
	call_deferred("_update_local_control")

func _update_local_control() -> void:
	if not is_node_ready():
		return
	var is_local := _is_local_authority()
	set_physics_process(is_local or _is_dedicated_server_player())
	camera.enabled = is_local
	if is_local:
		_apply_camera_zoom(GameManager.camera_zoom)

func _process(delta: float) -> void:
	if multiplayer.is_server() and not GameManager.is_hosting:
		return
	_update_draw_order()
	_update_rod_tip_socket()
	if _is_local_authority():
		# ponytail: snap only large drift; add sequence/replay reconciliation if collision mismatches are visible.
		return
	position = position.lerp(_remote_target_position, minf(1.0, REMOTE_LERP_SPEED * delta))

func _update_draw_order() -> void:
	z_index = PLAYER_RENDER_LAYER + floori(global_position.y)

func _physics_process(delta: float) -> void:
	if _is_dedicated_server_player():
		_server_physics(delta)
		return
	if not _is_local_authority():
		return
	var dir := Vector2.ZERO if _movement_locked or get_viewport().gui_get_focus_owner() is LineEdit else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	move_and_slide()
	_update_animation(dir)
	_last_input_dir = dir
	_send_input_if_due(delta)

func _update_animation(dir: Vector2) -> void:
	if _is_fishing:
		return
	if not sprite.sprite_frames:
		return
	if dir == Vector2.ZERO:
		sprite.play("idle")
	else:
		_set_sprite_direction(dir.x < 0)
		sprite.play("walk_right")

func _set_sprite_direction(flip: bool) -> void:
	sprite.flip_h = flip
	sprite.position = SPRITE_LEFT_POSITION if flip else SPRITE_RIGHT_POSITION

func start_fishing() -> void:
	_is_fishing = true
	_bobber_cast_quality = -1.0
	_last_input_dir = Vector2.ZERO
	if not _is_dedicated_server_player():
		set_physics_process(false)
	velocity = Vector2.ZERO
	sprite.play("fishing")
	_update_bobber(true)
	_send_input()

func play_hook() -> void:
	sprite.play("hook")
	_play_rod_recoil(3.0)
	_update_bobber(false)
	_send_input()

func stop_fishing() -> void:
	_is_fishing = false
	_bobber_cast_quality = -1.0
	var is_local := _is_local_authority()
	set_physics_process(is_local or _is_dedicated_server_player())
	sprite.play("idle")
	_update_bobber(false)
	_send_input()

func set_menu_hidden(menu_hidden: bool) -> void:
	_is_hidden_for_menu = menu_hidden
	visible = not menu_hidden
	if menu_hidden:
		_last_input_dir = Vector2.ZERO
	_update_bobber(_is_fishing)
	_send_input()

func set_movement_locked(locked: bool) -> void:
	_movement_locked = locked
	if locked:
		velocity = Vector2.ZERO
		_last_input_dir = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		_send_input()

func resume_from_menu_at(world_position: Vector2) -> void:
	global_position = world_position
	_is_hidden_for_menu = false
	visible = true
	velocity = Vector2.ZERO
	set_physics_process(_is_local_authority())
	if not _is_fishing and sprite.sprite_frames:
		sprite.play("idle")
	_update_bobber(_is_fishing)
	_send_input()
	call_deferred("_send_input")

func set_cast_quality(cast_quality: float) -> void:
	_bobber_cast_quality = clampf(cast_quality, 0.0, 1.0)
	_update_bobber(_is_fishing)
	_send_input()

func apply_cosmetics(skin_id: String, bobber_id: String) -> void:
	if _skin_id != skin_id:
		_skin_id = skin_id
		_apply_skin_frames()
	if bobber_visual and bobber_visual.has_method("set_skin"):
		bobber_visual.set_skin(bobber_id)

func _apply_skin_frames() -> void:
	var previous_animation := str(sprite.animation)
	if not SKIN_SHEETS.has(_skin_id):
		sprite.sprite_frames = _base_sprite_frames
	else:
		var sheets: Dictionary = SKIN_SHEETS[_skin_id]
		var frames := SpriteFrames.new()
		_add_skin_animation(frames, "fishing", sheets.fishing as Texture2D, 4, 5.0, true)
		_add_skin_animation(frames, "hook", sheets.hook as Texture2D, 6, 5.0, false)
		_add_skin_animation(frames, "idle", sheets.idle as Texture2D, 4, 5.0, true)
		_add_skin_animation(frames, "walk_right", sheets.walk_right as Texture2D, 6, 5.0, true)
		sprite.sprite_frames = frames
	sprite.play(previous_animation if sprite.sprite_frames.has_animation(previous_animation) else "idle")

func _add_skin_animation(frames: SpriteFrames, animation: String, sheet: Texture2D, count: int, speed: float, loop: bool) -> void:
	frames.add_animation(animation)
	frames.set_animation_speed(animation, speed)
	frames.set_animation_loop(animation, loop)
	for frame in range(count):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(frame * 48, 0, 48, 48)
		frames.add_frame(animation, atlas)

func play_bobber_cast(cast_quality: float) -> void:
	_bobber_cast_quality = clampf(cast_quality, 0.0, 1.0)
	if bobber_visual and bobber_visual.has_method("play_cast"):
		bobber_visual.play_cast(sprite.flip_h, _bobber_cast_quality)
	_play_rod_recoil(lerpf(2.0, 5.0, _bobber_cast_quality))
	_send_input()

func _play_rod_recoil(distance: float) -> void:
	if _recoil_tween and _recoil_tween.is_valid():
		_recoil_tween.kill()
	var rest := SPRITE_LEFT_POSITION if sprite.flip_h else SPRITE_RIGHT_POSITION
	var direction := 1.0 if sprite.flip_h else -1.0
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(sprite, "position", rest + Vector2(direction * distance, -1.0), 0.06)
	_recoil_tween.tween_property(sprite, "position", rest, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func show_catch(fish_id: String, trophy: bool = false, measurement: float = 0.0, measurement_unit: String = "") -> void:
	var fish := ItemRegistry.get_item(fish_id) as FishData
	if fish == null:
		return
	for effect in catch_sprite.get_children():
		effect.queue_free()
	catch_sprite.texture = _catch_texture_for(fish)
	if catch_sprite.texture == null:
		return
	catch_sprite.scale = Vector2.ONE * _catch_display_scale(catch_sprite.texture)
	catch_sprite.modulate = Color.WHITE
	catch_sprite.position = Vector2(8, -41)
	catch_sprite.visible = true
	_play_catch_effects(fish, trophy)
	if trophy and not measurement_unit.is_empty():
		show_chat_bubble("TROPHY %s! %.1f %s" % [fish.display_name, measurement, measurement_unit], 10.0)
	if _catch_tween:
		_catch_tween.kill()
	_catch_tween = create_tween().set_parallel(true)
	_catch_tween.tween_property(catch_sprite, "position:y", -53.0, CATCH_DISPLAY_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_catch_tween.tween_property(catch_sprite, "modulate:a", 0.0, 0.35).set_delay(CATCH_DISPLAY_SECONDS - 0.35)
	_catch_tween.finished.connect(func() -> void:
		catch_sprite.visible = false
		catch_sprite.texture = null
		for effect in catch_sprite.get_children():
			effect.queue_free()
	)

func show_chat_bubble(message: String, lifetime: float = CHAT_BUBBLE_LIFETIME) -> void:
	var bubble := chat_bubble.duplicate() as Label
	add_child(bubble)
	bubble.text = "%s: %s" % [player_name, message]
	bubble.autowrap_mode = TextServer.AUTOWRAP_OFF
	var font := chat_bubble.get_theme_font("font")
	var text_width := font.get_string_size(bubble.text, HORIZONTAL_ALIGNMENT_LEFT, -1, chat_bubble.get_theme_font_size("font_size")).x
	var width := maxf(text_width + CHAT_BUBBLE_PADDING, CHAT_BUBBLE_MIN_WIDTH)
	bubble.size = Vector2(width, CHAT_BUBBLE_HEIGHT)
	bubble.modulate = Color.WHITE
	bubble.show()
	_chat_messages.append(bubble)
	_layout_chat_messages()
	chat_tail.modulate = Color.WHITE
	chat_tail_inner.modulate = Color.WHITE
	name_label.hide()
	chat_tail.show()
	chat_tail_inner.show()
	var tween := create_tween()
	tween.tween_interval(lifetime - 0.4)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.4)
	tween.finished.connect(_remove_chat_message.bind(bubble))

func _layout_chat_messages() -> void:
	var bottom := CHAT_BUBBLE_BASELINE
	for index in range(_chat_messages.size() - 1, -1, -1):
		var bubble := _chat_messages[index]
		bubble.position = Vector2(-bubble.size.x * 0.5, bottom - bubble.size.y)
		bottom = bubble.position.y - CHAT_BUBBLE_GAP
	if _chat_messages.is_empty():
		chat_tail.hide()
		chat_tail_inner.hide()
		name_label.show()
		return
	var newest: Label = _chat_messages.back()
	chat_tail.position = Vector2(0.0, newest.position.y + newest.size.y)
	chat_tail_inner.position = chat_tail.position

func _remove_chat_message(bubble: Label) -> void:
	_chat_messages.erase(bubble)
	bubble.queue_free()
	_layout_chat_messages()

func _play_catch_effects(fish: FishData, trophy: bool = false) -> void:
	if fish.id.begins_with("junk_") or fish.id == "legendary_kraken":
		return
	if trophy:
		_play_catch_effect(CATCH_IMPACT_GOLD, Vector2i(48, 48), 1.5)
		_play_catch_effect(CATCH_SPARKLE_BLUE, Vector2i(32, 32), 2.25)
		return
	if fish.id in ["legendary_chest", "legendary_key"]:
		_play_catch_effect(CATCH_IMPACT_GOLD, Vector2i(48, 48))
	elif fish.rarity == "rare":
		_play_catch_effect(CATCH_IMPACT_BLUE, Vector2i(48, 48))
		_play_catch_effect(CATCH_SPARKLE_BLUE, Vector2i(32, 32), 1.75)
	elif fish.rarity in ["common", "uncommon"]:
		_play_catch_effect(CATCH_IMPACT_BLUE, Vector2i(48, 48))

func _play_catch_effect(sheet: Texture2D, frame_size: Vector2i, effect_scale: float = 1.0) -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("catch")
	var frame_count := sheet.get_width() / frame_size.x
	frames.set_animation_speed("catch", frame_count / (CATCH_DISPLAY_SECONDS - 0.35))
	frames.set_animation_loop("catch", false)
	for column in frame_count:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(Vector2(column * frame_size.x, 0), frame_size)
		frames.add_frame("catch", frame)
	var effect := AnimatedSprite2D.new()
	effect.sprite_frames = frames
	effect.animation = "catch"
	effect.scale = Vector2.ONE / catch_sprite.scale * effect_scale
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.show_behind_parent = true
	catch_sprite.add_child(effect)
	effect.play()

func apply_remote_state(pos: Vector2, animation: String, flip_h: bool, menu_hidden: bool, bobber_cast_quality: float = -1.0) -> void:
	_remote_target_position = pos
	if _is_local_authority():
		var correction := pos - position
		if correction.length() > 48.0:
			position = pos
	visible = not menu_hidden
	if sprite.sprite_frames and sprite.animation != animation:
		sprite.play(animation)
	_set_sprite_direction(flip_h)
	_bobber_cast_quality = -1.0 if bobber_cast_quality < 0.0 else clampf(bobber_cast_quality, 0.0, 1.0)
	_update_bobber(animation == "fishing")

func configure_spawned_player(spawn_position: Vector2) -> void:
	if position == Vector2.ZERO:
		position = spawn_position
	_remote_target_position = position
	_update_local_control()

func apply_server_input(input_dir: Vector2, animation: String, flip_h: bool, menu_hidden: bool, bobber_cast_quality: float = -1.0) -> void:
	if not _is_dedicated_server_player():
		return
	_server_input_dir = input_dir.limit_length(1.0)
	_is_hidden_for_menu = menu_hidden
	visible = not menu_hidden
	if animation == "fishing":
		_is_fishing = true
	elif _is_fishing and animation != "hook":
		_is_fishing = false
	if sprite.sprite_frames and sprite.animation != animation:
		sprite.play(animation)
	_set_sprite_direction(flip_h)
	_bobber_cast_quality = -1.0 if bobber_cast_quality < 0.0 else clampf(bobber_cast_quality, 0.0, 1.0)
	_update_bobber(_is_fishing)

func _send_input_if_due(delta: float) -> void:
	_state_send_accum += delta
	if _state_send_accum < STATE_SEND_INTERVAL:
		return
	_state_send_accum = 0.0
	_send_input()

func _send_input() -> void:
	if not _is_local_authority() or multiplayer.multiplayer_peer == null:
		return
	NetAPI.rpc_id(1, "c2s_player_input", _last_input_dir, str(sprite.animation), sprite.flip_h, _is_hidden_for_menu, _bobber_cast_quality)

func _is_local_authority() -> bool:
	return multiplayer.get_unique_id() == get_multiplayer_authority()

func _is_dedicated_server_player() -> bool:
	return multiplayer.is_server() and not GameManager.is_hosting

func _on_camera_zoom_changed(value: float) -> void:
	if _is_local_authority():
		_apply_camera_zoom(value)

func _apply_camera_zoom(value: float) -> void:
	camera.zoom = Vector2.ONE * clampf(value, 1.0, 4.0)

func _server_physics(delta: float) -> void:
	if _is_hidden_for_menu or _is_fishing:
		velocity = Vector2.ZERO
	else:
		velocity = _server_input_dir.limit_length(1.0) * SPEED
		_update_animation(_server_input_dir)
		move_and_slide()
	_broadcast_server_state_if_due(delta)

func _broadcast_server_state_if_due(delta: float) -> void:
	_server_state_send_accum += delta
	if _server_state_send_accum < STATE_SEND_INTERVAL:
		return
	_server_state_send_accum = 0.0
	NetAPI.rpc("notify_player_state", name.to_int(), position, str(sprite.animation), sprite.flip_h, _is_hidden_for_menu, _bobber_cast_quality)

func _update_bobber(force_visible: bool) -> void:
	if bobber_visual and bobber_visual.has_method("set_cast_visible"):
		_update_rod_tip_socket()
		var show_bobber := force_visible and not _is_hidden_for_menu and _bobber_cast_quality >= 0.0
		bobber_visual.set_cast_visible(show_bobber, sprite.flip_h, maxf(_bobber_cast_quality, 0.0))

func _update_rod_tip_socket() -> void:
	if bobber_visual == null or not bobber_visual.has_method("set_line_origin"):
		return
	var tips: Array = ROD_TIP_TEXTURE_POINTS.get(str(sprite.animation), [Vector2(42, 26)])
	var tip: Vector2 = tips[mini(sprite.frame, tips.size() - 1)] - Vector2(24, 24)
	if sprite.flip_h:
		tip.x = -tip.x
	bobber_visual.set_line_origin(sprite.position + tip)

func _catch_texture_for(fish: FishData) -> Texture2D:
	if fish.icon:
		return fish.icon
	if fish.sprite_frame < 0:
		return null
	var atlas := AtlasTexture.new()
	var frame := maxi(fish.sprite_frame, 0)
	var column := frame % FISH_SHEET_COLUMNS
	var row := floori(float(frame) / float(FISH_SHEET_COLUMNS))
	atlas.atlas = FISH_SHEET
	atlas.region = Rect2(
		Vector2(column * FISH_FRAME_SIZE.x, row * FISH_FRAME_SIZE.y),
		FISH_FRAME_SIZE
	)
	return atlas

func _catch_display_scale(texture: Texture2D) -> float:
	var visible_size := _visible_texture_size(texture)
	var max_size := maxf(visible_size.x, visible_size.y)
	if max_size <= 0.0:
		max_size = maxf(texture.get_width(), texture.get_height())
	return CATCH_DISPLAY_SIZE / max_size

func _visible_texture_size(texture: Texture2D) -> Vector2:
	if texture is AtlasTexture:
		return texture.get_size()
	var image := texture.get_image()
	if image == null:
		return texture.get_size()
	var rect := image.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return texture.get_size()
	return Vector2(rect.size)
