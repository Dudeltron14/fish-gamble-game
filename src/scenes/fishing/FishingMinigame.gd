extends CanvasLayer

signal completed

enum Stage { CAST, WAITING, REACT, REEL, RESULT }

const BASE_CAST_SPEED := 60.0
const REACT_WINDOW := 1.2  # base at difficulty 1.0, no hook
const REEL_BAR_WIDTH := 420.0
const CATCH_ZONE_FRAC := 0.18
const CURSOR_SPEED := 150.0
const FISH_SPEED_MAX_NORM := CURSOR_SPEED / REEL_BAR_WIDTH  # 0.357 — cursor speed in bar units
const FISH_SPEED_LERP := 2.5   # how fast speed transitions (higher = snappier changes)
const PROGRESS_RATE := 0.35    # base fill rate; multiplied by rod line_strength
const DRAIN_RATE := 0.35       # base drain rate; multiplied by fish difficulty

var _stage := Stage.CAST
var _cast_power := 0.0
var _cast_speed := BASE_CAST_SPEED
var _cast_filling := true   # true = filling toward 100, false = overshooting back down
var _cast_quality := 1.0    # 0.0–1.0; 1.0 = perfect (released exactly at 100)
var _hook_react_bonus := 0.0  # hook escape_reduction — widens react window
var _wait_timer := 0.0
var _react_timer := 0.0
var _fish_id := ""
var _difficulty := 1.0
var _line_strength := 1.0      # rod stat — scales how fast progress fills in zone
var _fish_pos := 0.5
var _fish_dir := 1.0
var _fish_dir_timer := 0.0
var _fish_speed := 0.0          # current speed (normalized bar units/s), slides smoothly
var _fish_speed_target := 0.0   # target to lerp toward
var _fish_speed_timer := 0.0    # countdown to next random speed change
var _cursor_pos := 0.5
var _reel_progress := 0.0

@onready var status: Label = %StatusLabel
@onready var cast_bar: ProgressBar = %CastBar
@onready var reel_container: Control = %ReelContainer
@onready var catch_zone: ColorRect = %CatchZone
@onready var cursor_rect: ColorRect = %Cursor
@onready var reel_label: Label = %ReelLabel
@onready var result_label: Label = %ResultLabel

func _ready() -> void:
	NetAPI.fishing_start.connect(_on_fishing_start)
	NetAPI.fishing_result.connect(_on_fishing_result)
	set_process(true)
	set_process_input(true)

func _process(delta: float) -> void:
	match _stage:
		Stage.CAST:     _process_cast(delta)
		Stage.WAITING:  _process_wait(delta)
		Stage.REACT:    _process_react(delta)
		Stage.REEL:     _process_reel(delta)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()

# ── Stages ────────────────────────────────────────────────────────────────────

func _process_cast(delta: float) -> void:
	if Input.is_action_pressed("interact"):
		cast_bar.visible = true
		if _cast_filling:
			_cast_power += _cast_speed * delta
			if _cast_power >= 100.0:
				_cast_power = 100.0
				_cast_filling = false   # start overshooting back down
		else:
			_cast_power -= _cast_speed * delta
		_cast_power = clampf(_cast_power, 0.0, 100.0)
		cast_bar.value = _cast_power
		# Bar colour: green at 100, yellow mid, red at 0 or overshooting low
		var t := _cast_power / 100.0
		cast_bar.modulate = Color(1.0 - t * 0.7, 0.3 + t * 0.7, 0.2)
		status.text = "Hold E… release to cast!" if _cast_filling else "Release! Overshooting…"
	elif _cast_power > 0.0 or not _cast_filling:
		_cast_quality = _cast_power / 100.0
		_enter_wait()

func _enter_wait() -> void:
	_stage = Stage.WAITING
	_cast_filling = true   # reset for next cast
	cast_bar.visible = false
	cast_bar.modulate = Color.WHITE
	# Perfect cast (1.0) → 1.5–3.5s wait; terrible cast (0.0) → 5.25–10.25s wait
	# (50% larger penalty delta vs original range)
	_wait_timer = randf_range(
		lerpf(5.25, 1.5, _cast_quality),
		lerpf(10.25, 3.5, _cast_quality)
	)
	var quality_text := "Perfect cast! 🎯" if _cast_quality > 0.95 else \
		("Good cast!" if _cast_quality > 0.70 else \
		("Weak cast…" if _cast_quality > 0.30 else "Terrible cast…"))
	status.text = "%s Waiting for a bite…" % quality_text
	NetAPI.rpc("c2s_fishing_start", _cast_quality)

func _process_wait(delta: float) -> void:
	_wait_timer -= delta
	if _wait_timer <= 0.0:
		_stage = Stage.REACT
		var diff_penalty := 1.0 + maxf(0.0, _difficulty - 1.0) * 0.35
		var cast_penalty := lerpf(0.5, 1.0, _cast_quality)  # terrible cast = 50% shorter window
		_react_timer = REACT_WINDOW / diff_penalty * (1.0 + _hook_react_bonus) * cast_penalty
		status.text = "!! BITE !! Press E!"

func _process_react(delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		# Server already pre-picked fish via notify_fishing_start; begin reel
		_enter_reel()
		return
	_react_timer -= delta
	if _react_timer <= 0.0:
		_show_result(false, "Too slow! The fish got away.")

func _enter_reel() -> void:
	_stage = Stage.REEL
	_fish_pos = 0.5
	_cursor_pos = 0.5
	_reel_progress = 0.0
	_fish_dir = 1.0 if randf() > 0.5 else -1.0
	_fish_dir_timer = randf_range(0.7, 1.8)
	# Speed slides between ~15% and 100% of difficulty-scaled max, never exceeding cursor speed
	var speed_max := minf(FISH_SPEED_MAX_NORM, _difficulty * 0.20)
	_fish_speed = speed_max * 0.5
	_fish_speed_target = _fish_speed
	_fish_speed_timer = randf_range(0.5, 1.5)
	reel_container.visible = true
	reel_label.visible = true
	status.text = "Reeling in…"
	_update_reel_visuals()

func _process_reel(delta: float) -> void:
	# Random direction changes keep the fish unpredictable
	_fish_dir_timer -= delta
	if _fish_dir_timer <= 0.0:
		_fish_dir *= -1.0
		_fish_dir_timer = randf_range(0.6, 1.6)

	# Speed slides randomly — pick new target every 0.5–1.5s, lerp smoothly toward it
	_fish_speed_timer -= delta
	if _fish_speed_timer <= 0.0:
		var speed_max := minf(FISH_SPEED_MAX_NORM, _difficulty * 0.20)
		var speed_min := speed_max * 0.15  # fish never fully stops
		_fish_speed_target = randf_range(speed_min, speed_max)
		_fish_speed_timer = randf_range(0.5, 1.5)
	_fish_speed = lerpf(_fish_speed, _fish_speed_target, FISH_SPEED_LERP * delta)
	_fish_pos += _fish_speed * _fish_dir * delta
	if _fish_pos >= 1.0 or _fish_pos <= 0.0:
		_fish_dir *= -1.0
		_fish_pos = clampf(_fish_pos, 0.0, 1.0)
		_fish_dir_timer = randf_range(0.5, 1.2)  # reset timer on edge bounce

	# Cursor movement
	var input_dir := Input.get_axis("move_left", "move_right")
	_cursor_pos = clampf(_cursor_pos + input_dir * CURSOR_SPEED * delta / REEL_BAR_WIDTH, 0.0, 1.0)

	# Overlap detection
	# Progress fills faster with better rods (line_strength); drains faster for harder fish (difficulty)
	var zone_half := (CATCH_ZONE_FRAC / _difficulty) * 0.5
	var overlapping := absf(_cursor_pos - _fish_pos) < zone_half
	if overlapping:
		_reel_progress = minf(_reel_progress + PROGRESS_RATE * _line_strength * delta, 1.0)
	else:
		_reel_progress = maxf(_reel_progress - DRAIN_RATE * _difficulty * delta, 0.0)

	_update_reel_visuals(overlapping)

	if _reel_progress >= 1.0:
		_finish_reel(true)
	elif _fish_pos <= 0.0 or _fish_pos >= 1.0:
		_finish_reel(false)

func _update_reel_visuals(overlapping: bool = false) -> void:
	var w := REEL_BAR_WIDTH
	var zone_half := (CATCH_ZONE_FRAC / _difficulty) * 0.5 * w
	catch_zone.offset_left = _fish_pos * w - zone_half
	catch_zone.offset_right = _fish_pos * w + zone_half
	cursor_rect.offset_left = _cursor_pos * w - 4.0
	cursor_rect.offset_right = _cursor_pos * w + 4.0
	cast_bar.value = _reel_progress * 100.0
	cast_bar.visible = true

	var pct := int(_reel_progress * 100.0)
	if overlapping:
		cast_bar.modulate = Color(0.3, 1.0, 0.45)
		status.text = "Reeling in… %d%%" % pct
	elif _reel_progress > 0.0:
		var secs_left := _reel_progress / (DRAIN_RATE * _difficulty)
		cast_bar.modulate = Color(1.0, 0.35 + _reel_progress * 0.35, 0.2)
		status.text = "Losing the fish! %d%% — %.1fs" % [pct, secs_left]
	else:
		cast_bar.modulate = Color(1.0, 0.4, 0.3)
		status.text = "Reeling in… 0%%"

func _finish_reel(success: bool) -> void:
	_stage = Stage.RESULT
	NetAPI.rpc("c2s_fishing_result", success)

# ── NetAPI callbacks ──────────────────────────────────────────────────────────

func _on_fishing_start(ok: bool, fish_id: String, difficulty: float, cast_speed: float, line_strength: float, wait_modifier: float, hook_react_bonus: float) -> void:
	if not ok:
		_show_result(false, "No fish nearby.")
		return
	_fish_id = fish_id
	_difficulty = difficulty
	_line_strength = line_strength
	_hook_react_bonus = hook_react_bonus
	_cast_speed = BASE_CAST_SPEED * cast_speed
	_wait_timer *= wait_modifier

func _on_fishing_result(caught: bool, fish_id: String, earned: int, new_balance: int) -> void:
	var fish: FishData = ItemRegistry.get_item(fish_id) as FishData
	var fish_name := fish.display_name if fish else fish_id
	if caught:
		GameManager.set_coins(new_balance)
		_show_result(true, "Caught %s! +%d coins" % [fish_name, earned])
	else:
		_show_result(false, "The %s escaped…" % fish_name)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _show_result(success: bool, msg: String) -> void:
	_stage = Stage.RESULT
	reel_container.visible = false
	reel_label.visible = false
	cast_bar.visible = false
	status.text = ""
	result_label.text = msg
	result_label.modulate = Color(0.3, 1.0, 0.4) if success else Color(1.0, 0.4, 0.4)
	result_label.visible = true
	result_label.scale = Vector2(0.6, 0.6)
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(result_label, "scale", Vector2.ONE, 0.35)
	await get_tree().create_timer(2.5).timeout
	_close()

func _close() -> void:
	completed.emit()
	queue_free()
