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
const ESCAPE_TIME_MAX := 3.0   # starting escape timer (seconds before fish gets away)

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
var _result_shown := false
var _reel_tick_timer := 0.0
var _auto_catch := false   # junk/chest/key — skip REACT+REEL, resolve on wait end
var _fish_pos := 0.5
var _fish_dir := 1.0
var _fish_dir_timer := 0.0
var _fish_speed := 0.0          # current speed (normalized bar units/s), slides smoothly
var _fish_speed_target := 0.0   # target to lerp toward
var _fish_speed_timer := 0.0    # countdown to next random speed change
var _cursor_pos := 0.5
var _reel_progress := 0.0
var _escape_timer := ESCAPE_TIME_MAX  # drains when off fish, fills when on — hits 0 = loss

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
	AudioManager.set_music_context("fishing")
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
	AudioManager.sfx("sfx_cast")
	status.text = "%s Waiting for a bite…" % quality_text
	NetAPI.rpc("c2s_fishing_start", _cast_quality)

func _process_wait(delta: float) -> void:
	_wait_timer -= delta
	if _wait_timer <= 0.0:
		if _auto_catch:
			# Junk / Chest / Key — no minigame, just resolve immediately
			_stage = Stage.RESULT
			NetAPI.rpc("c2s_fishing_result", true)
			return
		_stage = Stage.REACT
		var diff_penalty := 1.0 + maxf(0.0, _difficulty - 1.0) * 0.35
		var cast_penalty := lerpf(0.5, 1.0, _cast_quality)
		_react_timer = REACT_WINDOW / diff_penalty * (1.0 + _hook_react_bonus) * cast_penalty
		AudioManager.sfx("sfx_bite")
		status.text = "!! BITE !! Press E!"

func _process_react(delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		# Server already pre-picked fish via notify_fishing_start; begin reel
		_enter_reel()
		return
	_react_timer -= delta
	if _react_timer <= 0.0:
		NetAPI.rpc("c2s_fishing_result", false)
		AudioManager.sfx("sfx_miss")
		_show_result(false, "Too slow! The fish got away.")

func _enter_reel() -> void:
	_stage = Stage.REEL
	# Spawn distance scales with difficulty:
	# Easy fish start far from center (slow, need the chase distance).
	# Hard fish start close to center (erratic enough without a long chase).
	var d_norm      := clampf((_difficulty - 0.5) / 2.5, 0.0, 1.0)
	var min_dist    := lerpf(0.25, 0.07, d_norm)
	var max_dist    := lerpf(0.45, 0.23, d_norm)
	var zone_half_n := (CATCH_ZONE_FRAC / _difficulty) * 0.5
	var dist        := randf_range(min_dist, max_dist)
	var target      := (0.5 - dist) if randf() > 0.5 else (0.5 + dist)
	_fish_pos = clampf(target, zone_half_n, 1.0 - zone_half_n)
	_cursor_pos = 0.5
	_reel_progress = 0.0
	_escape_timer = ESCAPE_TIME_MAX
	_result_shown = false
	_auto_catch = false
	_fish_dir = 1.0 if randf() > 0.5 else -1.0
	_fish_dir_timer = randf_range(0.7, 1.8)
	# Speed slides between ~15% and 100% of difficulty-scaled max, never exceeding cursor speed
	var speed_max := minf(FISH_SPEED_MAX_NORM, _difficulty * 0.22)
	_fish_speed = speed_max * 0.5
	_fish_speed_target = _fish_speed
	_fish_speed_timer = randf_range(0.5, 1.5)
	reel_container.visible = true
	reel_label.visible = true
	status.text = "Reeling in…"
	_update_reel_visuals()

func _process_reel(delta: float) -> void:
	# Direction / behaviour timer — triggers a difficulty-scaled action
	_fish_dir_timer -= delta
	if _fish_dir_timer <= 0.0:
		_execute_fish_action()

	# Speed slides randomly — pick new target every 0.5–1.5s (overridden by some actions)
	_fish_speed_timer -= delta
	if _fish_speed_timer <= 0.0:
		var speed_max := minf(FISH_SPEED_MAX_NORM, _difficulty * 0.22)
		var speed_min := speed_max * 0.50
		_fish_speed_target = randf_range(speed_min, speed_max)
		_fish_speed_timer = randf_range(0.5, 1.5)
	_fish_speed = lerpf(_fish_speed, _fish_speed_target, FISH_SPEED_LERP * delta)
	_fish_pos += _fish_speed * _fish_dir * delta
	# Bounce when the EDGE of the catch zone would leave the bar, not the fish centre
	var zone_half_norm := (CATCH_ZONE_FRAC / _difficulty) * 0.5
	if (_fish_dir < 0.0 and _fish_pos - zone_half_norm <= 0.0) or \
	   (_fish_dir > 0.0 and _fish_pos + zone_half_norm >= 1.0):
		_fish_dir *= -1.0
		_fish_pos = clampf(_fish_pos, zone_half_norm, 1.0 - zone_half_norm)
		_fish_dir_timer = randf_range(0.5, 1.2)

	# Cursor movement
	var input_dir := Input.get_axis("move_left", "move_right")
	_cursor_pos = clampf(_cursor_pos + input_dir * CURSOR_SPEED * delta / REEL_BAR_WIDTH, 0.0, 1.0)

	# Overlap detection
	var zone_half := (CATCH_ZONE_FRAC / _difficulty) * 0.5
	var overlapping := absf(_cursor_pos - _fish_pos) < zone_half
	if overlapping:
		_reel_progress = minf(_reel_progress + PROGRESS_RATE * _line_strength * delta, 1.0)
		_escape_timer  = minf(_escape_timer  + PROGRESS_RATE * _line_strength * delta, ESCAPE_TIME_MAX)
		_reel_tick_timer -= delta
		if _reel_tick_timer <= 0.0:
			AudioManager.sfx("sfx_reel_tick")
			_reel_tick_timer = 0.12
	else:
		_reel_tick_timer = 0.0
		_reel_progress = maxf(_reel_progress - DRAIN_RATE * _difficulty * delta, 0.0)
		_escape_timer  = maxf(_escape_timer  - DRAIN_RATE * _difficulty * delta, 0.0)

	_update_reel_visuals(overlapping)

	if _reel_progress >= 1.0:
		_finish_reel(true)
	elif _escape_timer <= 0.0:
		_finish_reel(false)

func _pick_fish_action() -> String:
	# d_norm: 0.0 at difficulty 0.5 (easy) → 1.0 at difficulty 3.0 (extreme)
	var d_norm := clampf((_difficulty - 0.5) / 2.5, 0.0, 1.0)
	var w := {
		"flip":       lerpf(0.20, 0.35, d_norm),
		"continue":   lerpf(0.15, 0.25, d_norm),
		"slowdown":   lerpf(0.30, 0.00, d_norm),
		"hover":      lerpf(0.20, 0.00, d_norm),
		"burst":      lerpf(0.05, 0.25, d_norm),
		"shimmy":     lerpf(0.00, 0.15, d_norm),
		"freezedash": lerpf(0.10, 0.00, d_norm),
	}
	var total := 0.0
	for v: float in w.values(): total += v
	var roll := randf() * total
	var cumulative := 0.0
	for action: String in w:
		cumulative += w[action]
		if roll < cumulative:
			return action
	return "flip"

func _execute_fish_action() -> void:
	var speed_max := minf(FISH_SPEED_MAX_NORM, _difficulty * 0.22)
	match _pick_fish_action():
		"flip":
			_fish_dir *= -1.0
			_fish_dir_timer = randf_range(0.6, 1.6)
		"continue":
			_fish_dir_timer = randf_range(0.6, 1.6)
		"slowdown":
			_fish_speed_target = speed_max * 0.15
			_fish_speed_timer  = randf_range(0.8, 1.8)
			_fish_dir_timer    = randf_range(1.0, 2.5)
		"hover":
			_fish_speed_target = speed_max * 0.03
			_fish_speed_timer  = randf_range(1.5, 3.5)
			_fish_dir_timer    = randf_range(2.0, 4.0)
		"burst":
			if randf() > 0.5: _fish_dir *= -1.0
			_fish_speed_target = speed_max
			_fish_speed_timer  = randf_range(0.2, 0.6)
			_fish_dir_timer    = randf_range(0.3, 0.7)
		"shimmy":
			_fish_dir *= -1.0
			_fish_speed_target = speed_max * 0.8
			_fish_speed_timer  = randf_range(0.1, 0.3)
			_fish_dir_timer    = randf_range(0.1, 0.25)
		"freezedash":
			_fish_speed_target = 0.0
			_fish_speed_timer  = randf_range(0.5, 1.2)
			_fish_dir          = 1.0 if randf() > 0.5 else -1.0
			_fish_dir_timer    = randf_range(0.4, 0.8)

func _update_reel_visuals(overlapping: bool = false) -> void:
	var w := REEL_BAR_WIDTH
	var zone_half := (CATCH_ZONE_FRAC / _difficulty) * 0.5 * w
	catch_zone.offset_left  = clampf(_fish_pos * w - zone_half, 0.0, w)
	catch_zone.offset_right = clampf(_fish_pos * w + zone_half, 0.0, w)
	cursor_rect.offset_left = _cursor_pos * w - 4.0
	cursor_rect.offset_right = _cursor_pos * w + 4.0
	cast_bar.value = _reel_progress * 100.0
	cast_bar.visible = true

	var pct := int(_reel_progress * 100.0)
	var escape_pct := _escape_timer / ESCAPE_TIME_MAX
	if overlapping:
		cast_bar.modulate = Color(0.3, 1.0, 0.45)
		status.text = "Reeling in… %d%%" % pct
	elif _escape_timer > 0.0:
		cast_bar.modulate = Color(1.0, 0.2 + escape_pct * 0.5, 0.1)
		status.text = "Losing the fish! %d%% — %.2fs" % [pct, _escape_timer]
	else:
		cast_bar.modulate = Color(1.0, 0.2, 0.1)
		status.text = "Fish escaping!"

func _finish_reel(success: bool) -> void:
	_stage = Stage.RESULT
	NetAPI.rpc("c2s_fishing_result", success)

# ── NetAPI callbacks ──────────────────────────────────────────────────────────

func _on_fishing_start(ok: bool, fish_id: String, difficulty: float, cast_speed: float, line_strength: float, wait_modifier: float, hook_react_bonus: float, auto_catch: bool) -> void:
	if not ok:
		_show_result(false, "No fish nearby.")
		return
	_fish_id = fish_id
	_difficulty = difficulty
	_line_strength = line_strength
	_hook_react_bonus = hook_react_bonus
	_auto_catch = auto_catch
	_cast_speed = BASE_CAST_SPEED * cast_speed
	_wait_timer *= wait_modifier

func _on_fishing_result(caught: bool, fish_id: String, earned: int, new_balance: int) -> void:
	if _result_shown:
		return  # _show_result already fired (e.g. missed react showed result before server responded)
	var fish: FishData = ItemRegistry.get_item(fish_id) as FishData
	var fish_name := fish.display_name if fish else fish_id
	if caught:
		GameManager.set_coins(new_balance)
		AudioManager.sfx("sfx_catch")
		AudioManager.sfx("sfx_coins")
		_show_result(true, "Caught %s! +%d coins" % [fish_name, earned])
	else:
		AudioManager.sfx("sfx_miss")
		_show_result(false, "The %s escaped…" % fish_name)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _show_result(success: bool, msg: String) -> void:
	_stage = Stage.RESULT
	_result_shown = true
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
	AudioManager.set_music_context("world")
	completed.emit()
	queue_free()
