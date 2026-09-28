shader_type canvas_item;

uniform float scroll_speed = 1.0;
uniform float repeat_count = 1.0;

void fragment() {
	// Offset the UV.x by time to create the scrolling effect
	vec2 moving_uv = vec2(UV.x * repeat_count - (TIME * scroll_speed), UV.y);
	
	// Apply the texture with the new UV
	vec4 tex_color = texture(TEXTURE, moving_uv);
	
	// Multiply by the Line2D's color/gradient
	COLOR = tex_color * COLOR;
}