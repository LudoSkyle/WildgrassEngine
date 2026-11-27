// A still of the screen going away: all at once as `progress` goes from 0
// to 1 (a dissolve), or through a transition picture, its dark parts first,
// softened over `vague`.
shader_type canvas_item;

uniform float progress = 0.0;
uniform bool use_mask = false;
uniform sampler2D mask : filter_linear;
uniform float vague = 0.157;

void fragment() {
	vec4 still = texture(TEXTURE, UV);
	float shown = 1.0 - progress;
	if (use_mask) {
		float level = texture(mask, UV).r;
		float edge = progress * (1.0 + vague) - vague;
		shown = clamp((level - edge) / vague, 0.0, 1.0);
	}
	COLOR = vec4(still.rgb, still.a * shown);
}
