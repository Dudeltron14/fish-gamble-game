extends Node2D

const LIFETIME := 3.2
var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed = minf(elapsed + delta, LIFETIME)
	queue_redraw()
	if elapsed >= LIFETIME:
		queue_free()

func _draw() -> void:
	var fade := 1.0 - elapsed / LIFETIME
	var spin := elapsed * 7.0
	draw_circle(Vector2.ZERO, 48.0, Color(0.025, 0.01, 0.06, 0.42 * fade))
	for smoke in 8:
		var angle := spin * 0.32 + smoke * TAU / 8.0
		var radius := 24.0 + sin(spin + smoke) * 10.0
		draw_circle(Vector2(cos(angle), sin(angle) * 0.62) * radius, 14.0 + sin(spin * 0.7 + smoke) * 4.0, Color(0.08, 0.02, 0.13, 0.16 * fade))
	for ring in 5:
		var radius := 22.0 + ring * 10.0 + sin(spin + ring) * 3.0
		var start := spin * (1.0 + ring * 0.12) + ring * TAU / 3.0
		draw_arc(Vector2.ZERO, radius, start, start + TAU * 0.62, 18, Color(0.20, 0.03, 0.34, (0.92 - ring * 0.15) * fade), 2.5, false)
		draw_arc(Vector2.ZERO, radius - 3.0, start + TAU * 0.42, start + TAU * 0.84, 12, Color(0.53, 0.09, 0.65, 0.7 * fade), 1.5, false)
	var eye_pulse := 0.6 + sin(spin * 1.7) * 0.4
	for eye in [Vector2(-6.0, -7.0), Vector2(6.0, -7.0)]:
		draw_circle(eye, 4.5, Color(0.38, 0.01, 0.02, 0.28 * fade * eye_pulse))
		draw_circle(eye, 1.5, Color(1.0, 0.12, 0.02, fade * eye_pulse))
