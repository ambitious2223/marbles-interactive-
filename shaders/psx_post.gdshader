shader_type canvas_item;
render_mode unshaded;

// PS1-flavoured post-processing: ordered dithering + colour quantization.
// Applied by a full-screen ColorRect on a high CanvasLayer (see Main._add_psx_post).

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float color_levels : hint_range(2.0, 64.0) = 20.0;
uniform float dither_amount : hint_range(0.0, 2.0) = 1.0;

// Interleaved gradient noise — cheap ordered dither, no lookup table needed.
float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float d = (ign(FRAGCOORD.xy) - 0.5) * dither_amount;
	col += d / color_levels;
	col = floor(col * color_levels + 0.5) / color_levels;
	COLOR = vec4(col, 1.0);
}
