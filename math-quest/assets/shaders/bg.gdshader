shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_radius : hint_range(0.0, 10.0) = 4.0;
uniform float paint_stroke_size : hint_range(0.0, 50.0) = 15.0;

// Added: Hash function to generate the irregular brush stroke noise
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Added: Setup for screen sampling and smudge effect variables
	vec2 uv = SCREEN_UV;
	vec2 pixel_size = SCREEN_PIXEL_SIZE;
	vec4 col = vec4(0.0);
	float weight_sum = 0.0;

	// {to-do} Optimize the nested loops if performance drops on low-end mobile devices
	for (float x = -blur_radius; x <= blur_radius; x += 1.0) {
		for (float y = -blur_radius; y <= blur_radius; y += 1.0) {
			vec2 offset = vec2(x, y);
			
			// Added: Smearing the sample points using the hash function to create a painted look
			float stroke_noise = hash(floor((uv * 1000.0) / paint_stroke_size) + offset) * 2.0 - 1.0;
			vec2 smudge = offset + stroke_noise * (paint_stroke_size * 0.1);
			
			vec2 sample_uv = uv + smudge * pixel_size;
			col += texture(screen_texture, sample_uv);
			weight_sum += 1.0;
		}
	}

	COLOR = col / weight_sum;
}