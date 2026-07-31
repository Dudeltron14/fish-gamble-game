shader_type canvas_item;
render_mode unshaded;

uniform vec4 glow_color : source_color = vec4(0.25, 0.72, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform bool kraken_mode = false;

float nearby_alpha(vec2 uv, vec2 pixel) {
	float alpha = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			alpha = max(alpha, texture(TEXTURE, uv + vec2(float(x), float(y)) * pixel).a);
		}
	}
	return alpha;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float halo = max(0.0, nearby_alpha(UV, TEXTURE_PIXEL_SIZE) - source.a);
	float pulse = 0.62 + sin(TIME * (kraken_mode ? 10.0 : 7.0)) * 0.38;
	vec3 color = mix(source.rgb, glow_color.rgb, source.a * 0.18 * strength * pulse);
	if (kraken_mode) {
		float left_eye = smoothstep(0.09, 0.0, distance(UV, vec2(0.39, 0.34)));
		float right_eye = smoothstep(0.09, 0.0, distance(UV, vec2(0.61, 0.34)));
		color += vec3(1.0, 0.18, 0.03) * (left_eye + right_eye) * pulse * 1.25;
	}
	COLOR = vec4(mix(glow_color.rgb, color, source.a), max(source.a, halo * strength * pulse));
}
