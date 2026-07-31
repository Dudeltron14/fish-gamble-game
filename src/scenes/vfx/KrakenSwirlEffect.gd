extends Node2D

const LIFETIME := 1.65
var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed = minf(elapsed + delta, LIFETIME)
	queue_redraw()
	if elapsed >= LIFETIME:
		queue_free()

func _draw() -> void:
	var fade := 1.0 - elapsed / LIFETIME
	var spin := elapsed * 7.0
	draw_circle(Vector2.ZERO, 31.0, Color(0.035, 0.01, 0.08, 0.34 * fade))
	for ring in 3:
		var radius := 18.0 + ring * 8.0 + sin(spin + ring) * 2.0
		var start := spin * (1.0 + ring * 0.12) + ring * TAU / 3.0
		draw_arc(Vector2.ZERO, radius, start, start + TAU * 0.62, 18, Color(0.20, 0.03, 0.34, (0.92 - ring * 0.15) * fade), 2.5, false)
		draw_arc(Vector2.ZERO, radius - 3.0, start + TAU * 0.42, start + TAU * 0.84, 12, Color(0.53, 0.09, 0.65, 0.7 * fade), 1.5, false)
	var eye_pulse := 0.6 + sin(spin * 1.7) * 0.4
	for eye in [Vector2(-6.0, -7.0), Vector2(6.0, -7.0)]:
		draw_circle(eye, 4.5, Color(0.38, 0.01, 0.02, 0.28 * fade * eye_pulse))
		draw_circle(eye, 1.5, Color(1.0, 0.12, 0.02, fade * eye_pulse))
