shader_type canvas_item;
render_mode unshaded;

// Single-pass replacement for any number of PointLight2D nodes (no shadows).
// Math matches Godot's 2D lighting:  final = albedo * (ambient + sum(lights))
// The framebuffer already holds albedo * ambient (CanvasModulate), so:
//   final = screen * (ambient + sum(lights)) / ambient

const int MAX_LIGHTS = 64;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D falloff_ramp : filter_linear, repeat_disable;

uniform vec3 ambient = vec3(1.0);               // CanvasModulate color
uniform vec2 view_size = vec2(1152.0, 648.0);   // visible rect in pixels
uniform int light_count = 0;
uniform vec4 light_pos_radius[MAX_LIGHTS];      // xy = pos (px), z = radius (px), w = 1.0 if light ignores CanvasModulate
uniform vec4 light_rgb[MAX_LIGHTS];             // rgb = color (premultiplied by energy unless ignoring), a = signed energy

void fragment() {
	vec4 scene = texture(screen_tex, SCREEN_UV);
	vec2 p = SCREEN_UV * view_size;

	vec3 amb = max(ambient, vec3(0.001));
	vec3 m = amb; // per-pixel light multiplier, starts at the CanvasModulate color

	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= light_count) {
			break;
		}
		vec4 g = light_pos_radius[i];
		float t = distance(p, g.xy) / g.z;
		if (t >= 1.0) {
			continue;
		}
		vec4 r = textureLod(falloff_ramp, vec2(t, 0.5), 0.0);
		vec3 shape = r.rgb * r.a;
		vec4 c = light_rgb[i];
		if (g.w > 0.5) {
			// Ignores CanvasModulate: lit area fades from ambient to the light's own
			// color, so the modulate tint is replaced instead of added to.
			float w = clamp(max(shape.r, max(shape.g, shape.b)) * c.a, 0.0, 1.0);
			m = mix(m, c.rgb * shape / max(max(shape.r, max(shape.g, shape.b)), 0.0001), w);
		} else {
			m += c.rgb * shape;
		}
	}

	COLOR = vec4(scene.rgb * (max(m, vec3(0.0)) / amb), 1.0);
}
