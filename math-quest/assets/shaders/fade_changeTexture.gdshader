shader_type canvas_item;

uniform sampler2D new_texture;
uniform float transition_value : hint_range(0.0, 1.0) = 0.0;
// Added uniform to accept the grayscale mask texture for the dissolve effect
uniform sampler2D mask_texture; 

void fragment() {
    vec4 old_tex = texture(TEXTURE, UV);
    vec4 new_tex = texture(new_texture, UV);
    
    // Added mask reading and updated the mix factor to create a dissolve threshold
    float mask_val = texture(mask_texture, UV).r;
    float dissolve_factor = step(mask_val, transition_value);
    
    COLOR = mix(old_tex, new_tex, dissolve_factor);
}