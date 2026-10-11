shader_type canvas_item;

// Full-screen multiply: world_color * (ambient + lights).
// This is the same formula Godot's real 2D lighting ends up with, except the
// lights were drawn ONCE into a small texture instead of re-drawing every
// sprite once per light.
render_mode unshaded, blend_mul;

uniform sampler2D light_map : filter_linear, repeat_disable;
uniform float dither : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec3 light = texture(light_map, UV).rgb;

	// Interleaved gradient noise, hides banding from the low-res light map.
	float n = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715)))) - 0.5;
	light += n * (dither / 255.0);

	COLOR = vec4(max(light, vec3(0.0)), 1.0);
}
