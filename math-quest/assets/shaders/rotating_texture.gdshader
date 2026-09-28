shader_type canvas_item;

uniform float rotation_speed = 2.0;

uniform float alpha : hint_range(0.0, 1.0) = 1.0; 

void fragment() {
    float angle = TIME * rotation_speed;
    
    float cos_angle = cos(angle);
    float sin_angle = sin(angle);
    
    vec2 shifted_uv = UV - vec2(0.5);
    
    vec2 rotated_uv = vec2(
        shifted_uv.x * cos_angle - shifted_uv.y * sin_angle,
        shifted_uv.x * sin_angle + shifted_uv.y * cos_angle
    );
    
    rotated_uv += vec2(0.5);
    
    // Check if the rotated UVs are outside the bounds
    if (rotated_uv.x < 0.0 || rotated_uv.x > 1.0 || rotated_uv.y < 0.0 || rotated_uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0); // Force pure transparent empty space
    } else {
        // Read the texture color
        vec4 tex_color = texture(TEXTURE, rotated_uv);
        
        // Multiply the original image's alpha by your slider value
        tex_color.a *= alpha;
        
        // Output the final color
        COLOR = tex_color; 
    }
}