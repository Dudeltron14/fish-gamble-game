extends CanvasLayer

signal completed

enum Stage { CAST, WAITING, REACT, REEL, RESULT }

const CAST_SPEED := 60.0
const REACT_WINDOW := 1.5
const REEL_BAR_WIDTH := 420.0
const CATCH_ZONE_FRAC := 0.25   # fraction of bar width (reduced by difficulty)
const CURSOR_SPEED := 220.0
const PROGRESS_RATE := 1.0      # seconds of overlap needed to catch
const DRAIN_RATE := 0.6

var _stage := Stage.CAST
var _cast_power := 0.0
var _wait_timer := 0.0
var _react_timer := 0.0
var _fish_id := ""
var _difficulty := 1.0
var _fish_pos := 0.5      # 0..1 normalized position in bar
var _fish_dir := 1.0
var _cursor_pos := 0.5    # 0..1
var _reel_progress := 0.0 # 0..1 fill to win

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
	if Input.is_action_pressed("ui_accept"):
		_cast_power = minf(_cast_power + CAST_SPEED * delta, 100.0)
		cast_bar.value = _cast_power
		cast_bar.visible = true
		status.text = "Hold SPACE… release to cast!"
	elif _cast_power > 0.0:
		_enter_wait()

func _enter_wait() -> void:
	_stage = Stage.WAITING
	cast_bar.visible = false
	_wait_timer = randf_range(1.5, 3.5)
	status.text = "Waiting for a bite…"
	NetAPI.rpc("c2s_fishing_start")

func _process_wait(delta: float) -> void:
	_wait_timer -= delta
	if _wait_timer <= 0.0:
		_stage = Stage.REACT
		_react_timer = REACT_WINDOW
		status.text = "!! BITE !! Press SPACE!"

func _process_react(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
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
	reel_container.visible = true
	reel_label.visible = true
	status.text = "Reeling in…"
	_update_reel_visuals()

func _process_reel(delta: float) -> void:
	# Fish oscillates, speed scales with difficulty
	var fish_speed := 0.18 * _difficulty
	_fish_pos += fish_speed * _fish_dir * delta * 60.0 * delta
	if _fish_pos >= 1.0 or _fish_pos <= 0.0:
		_fish_dir *= -1.0
		_fish_pos = clampf(_fish_pos, 0.0, 1.0)

	# Cursor movement
	var input_dir := Input.get_axis("ui_left", "ui_right")
	_cursor_pos = clampf(_cursor_pos + input_dir * CURSOR_SPEED * delta / REEL_BAR_WIDTH, 0.0, 1.0)

	# Overlap detection
	var zone_half := (CATCH_ZONE_FRAC / _difficulty) * 0.5
	var overlapping := absf(_cursor_pos - _fish_pos) < zone_half
	if overlapping:
		_reel_progress = minf(_reel_progress + PROGRESS_RATE * delta, 1.0)
	else:
		_reel_progress = maxf(_reel_progress - DRAIN_RATE * delta, 0.0)

	_update_reel_visuals()

	if _reel_progress >= 1.0:
		_finish_reel(true)
	elif _fish_pos <= 0.0 or _fish_pos >= 1.0:
		_finish_reel(false)

func _update_reel_visuals() -> void:
	var w := REEL_BAR_WIDTH
	var zone_half := (CATCH_ZONE_FRAC / _difficulty) * 0.5 * w
	catch_zone.offset_left = _fish_pos * w - zone_half
	catch_zone.offset_right = _fish_pos * w + zone_half
	cursor_rect.offset_left = _cursor_pos * w - 4.0
	cursor_rect.offset_right = _cursor_pos * w + 4.0
	cast_bar.value = _reel_progress * 100.0
	cast_bar.visible = true

func _finish_reel(success: bool) -> void:
	_stage = Stage.RESULT
	NetAPI.rpc("c2s_fishing_result", success)

# ── NetAPI callbacks ──────────────────────────────────────────────────────────

func _on_fishing_start(ok: bool, fish_id: String, difficulty: float) -> void:
	if not ok:
		_show_result(false, "No fish nearby.")
		return
	_fish_id = fish_id
	_difficulty = difficulty

func _on_fishing_result(caught: bool, fish_id: String, coins: int) -> void:
	var fish: FishData = ItemRegistry.get_item(fish_id) as FishData
	var name := fish.display_name if fish else fish_id
	if caught:
		GameManager.add_coins(coins)
		_show_result(true, "Caught %s! +%d coins" % [name, coins])
	else:
		_show_result(false, "The %s escaped…" % name)

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
	await get_tree().create_timer(2.5).timeout
	_close()

func _close() -> void:
	completed.emit()
	queue_free()
