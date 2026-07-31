shader_type canvas_item;
render_mode unshaded;

uniform float age : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 point = (UV - vec2(0.5)) * vec2(1.0, 0.52);
	float distance_from_center = length(point);
	float radius = mix(0.10, 0.58, age);
	float ring = smoothstep(0.035, 0.0, abs(distance_from_center - radius));
	float inner_radius = max(0.0, radius - 0.18);
	float inner_ring = smoothstep(0.022, 0.0, abs(distance_from_center - inner_radius));
	float fade = 1.0 - age;
	COLOR = vec4(0.72, 0.90, 1.0, (ring * 0.55 + inner_ring * 0.28) * fade);
}
