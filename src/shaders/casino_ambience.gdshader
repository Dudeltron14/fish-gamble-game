shader_type canvas_item;
render_mode unshaded;

float noise(vec2 point) {
	return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float vignette = smoothstep(0.28, 0.72, length((uv - vec2(0.5)) * vec2(1.15, 0.82)));
	float smoke = smoothstep(0.54, 0.78, noise(floor((uv + vec2(TIME * 0.004, -TIME * 0.009)) * 18.0))) * (1.0 - uv.y) * 0.16;
	float lamp = smoothstep(0.34, 0.0, distance(uv, vec2(0.5, 0.26))) * (0.48 + sin(TIME * 4.0) * 0.07);
	vec3 color = mix(vec3(0.035, 0.018, 0.012), vec3(0.42, 0.20, 0.055), lamp);
	COLOR = vec4(color, vignette * 0.26 + smoke + lamp * 0.06);
}
