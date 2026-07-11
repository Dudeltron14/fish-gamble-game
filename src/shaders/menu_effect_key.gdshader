shader_type canvas_item;

uniform float saturation_cutoff : hint_range(0.0, 1.0) = 0.12;
uniform float brightness_cutoff : hint_range(0.0, 1.0) = 0.42;
uniform float alpha_multiplier : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float max_channel = max(color.r, max(color.g, color.b));
	float min_channel = min(color.r, min(color.g, color.b));
	float saturation = max_channel - min_channel;
	if (color.a < 0.05 || (saturation < saturation_cutoff && max_channel > brightness_cutoff)) {
		color.a = 0.0;
	}
	color.a *= alpha_multiplier;
	COLOR = color * COLOR;
}
