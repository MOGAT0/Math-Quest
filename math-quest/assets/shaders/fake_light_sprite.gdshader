shader_type canvas_item;
render_mode unshaded; // default blend (mix); we write the final pixel ourselves

// Scene behind the light (already darkened by CanvasModulate).
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;

// MUST match your CanvasModulate color. Set by fake_light_sprite.gd.
uniform vec3 ambient = vec3(1.0);

// Multiplier the scene gets at the center of the light (1,1,1 = true colors).
uniform vec4 light_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float intensity = 1.0;
uniform float radius = 0.5;
uniform float falloff = 2.0;

// Only needed if the sprite is in the same canvas as the CanvasModulate
// (requires Project Settings > Rendering > Viewport > HDR 2D).
uniform bool compensate_canvas_modulate = false;

void fragment() {
	float dist = distance(UV, vec2(0.5));

	float w = 1.0 - smoothstep(0.0, radius, dist);
	w = pow(w, falloff);
	w = clamp(w * intensity, 0.0, 1.0) * light_color.a;

	// {to-do} Implement noise-based flickering or pulsing (multiply w by a noise value)

	vec3 amb = max(ambient, vec3(0.001));
	// Light replaces the ambient tint instead of adding a flat glow on top of it:
	// ambient at the edge -> light_color at the center.
	vec3 m = mix(amb, light_color.rgb, w);

	// scene = albedo * ambient  ->  albedo * m = scene * m / ambient
	vec3 result = texture(screen_tex, SCREEN_UV).rgb * m / amb;

	COLOR = vec4(compensate_canvas_modulate ? result / amb : result, 1.0);
}
