// RPG Maker's tone: gray takes the colours toward their grey, then red,
// green and blue are added; each -255 to 255 (gray 0 to 255). On the screen
// under it (`use_screen`), or on its own texture (a picture).
shader_type canvas_item;

uniform vec4 tone = vec4(0.0);
uniform bool use_screen = false;
uniform sampler2D screen : hint_screen_texture, filter_nearest;

vec4 toned(vec4 color) {
	float grey = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(color.rgb, vec3(grey), tone.w / 255.0);
	color.rgb = clamp(color.rgb + tone.rgb / 255.0, 0.0, 1.0);
	return color;
}

void fragment() {
	vec4 color = use_screen ? texture(screen, SCREEN_UV) : texture(TEXTURE, UV) * COLOR;
	COLOR = toned(color);
}
