extends Control

var _ends_at_ms := 0
var _duration := 1.0
@onready var label: Label = $Label

func set_countdown(seconds: float, phase: String) -> void:
	visible = seconds > 0.0
	_duration = maxf(seconds, 0.1)
	_ends_at_ms = Time.get_ticks_msec() + int(seconds * 1000.0)
	tooltip_text = "Auto-stand when this turn ends." if phase == "player_turns" else "Round begins when this timer ends."
	queue_redraw()

func _process(_delta: float) -> void:
	if not visible:
		return
	var remaining := maxf(0.0, float(_ends_at_ms - Time.get_ticks_msec()) / 1000.0)
	label.text = "%ds" % ceili(remaining)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.38
	var remaining := clampf(float(_ends_at_ms - Time.get_ticks_msec()) / 1000.0, 0.0, _duration)
	var progress := remaining / _duration
	draw_circle(center, radius, Color(0.08, 0.06, 0.03, 0.88))
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 24, Color(0.95, 0.67, 0.16), 2.0, true)
