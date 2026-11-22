shader_type canvas_item;
render_mode unshaded;

// A weather's tone over the screen already drawn: the colour taken first
// (gray), then the tone added. It works on the world as it is by day: the
// day's tint is taken off first and put back after, so a weather darkens
// night in proportion as it darkens day.

uniform sampler2D screen : hint_screen_texture, filter_nearest, repeat_disable;
// Added to each channel, from -1 to 1.
uniform vec3 tone = vec3(0.0);
// The colour taken from the screen first, 0 to 1.
uniform float gray = 0.0;

global uniform vec4 day_tint : source_color;

void fragment() {
	vec3 day = max(day_tint.rgb, vec3(0.05));
	vec3 color = texture(screen, SCREEN_UV).rgb / day;
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = max(mix(color, vec3(luma), gray) + tone, vec3(0.0));
	// Bounded only at the end: a lamp's light may go past night's tint.
	COLOR = vec4(clamp(color * day, 0.0, 1.0), 1.0);
}
