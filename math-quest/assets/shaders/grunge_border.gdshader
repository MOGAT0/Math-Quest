shader_type canvas_item;

// ---- Colors ----
uniform vec4 border_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool fill_center = true; 

uniform float animation_speed = 1.0;
uniform float smoke_speed = 0.5;

// ---- Border shape ----
uniform vec2 rect_size = vec2(512.0, 512.0); 

uniform float border_left : hint_range(0.0, 300.0) = 40.0;
uniform float border_right : hint_range(0.0, 300.0) = 40.0;
uniform float border_top : hint_range(0.0, 300.0) = 40.0;
uniform float border_bottom : hint_range(0.0, 300.0) = 40.0;

uniform float jaggedness : hint_range(0.0, 200.0) = 35.0;      
uniform float softness : hint_range(0.5, 20.0) = 2.0;          
uniform float noise_scale : hint_range(0.001, 0.2) = 0.02;    

// ---- Smoke ----
uniform vec4 smoke_color : source_color = vec4(0.7, 0.7, 0.7, 1.0);
uniform float smoke_scale : hint_range(0.001, 0.2) = 0.015;
uniform float smoke_opacity : hint_range(0.0, 1.0) = 0.4;

// ---------------- Noise helpers ----------------
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 5; i++) {
        value += amplitude * value_noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}
// -------------------------------------------------

void fragment() {
    vec2 pixel_pos = UV * rect_size;

    float dist_left = pixel_pos.x;
    float dist_right = rect_size.x - pixel_pos.x;
    float dist_top = pixel_pos.y;
    float dist_bottom = rect_size.y - pixel_pos.y;

    vec2 time_offset1 = vec2(TIME * animation_speed * 15.0, TIME * animation_speed * 10.0);
    vec2 time_offset3 = vec2(-TIME * smoke_speed * 10.0, TIME * smoke_speed * 8.0);

    float n1 = fbm(pixel_pos * noise_scale + time_offset1);
    
    float noise_offset = (n1 - 0.5) * 2.0 * jaggedness;

    float b_left = border_left + noise_offset;
    float b_right = border_right + noise_offset;
    float b_top = border_top + noise_offset;
    float b_bottom = border_bottom + noise_offset;

    float mask_left = 1.0 - smoothstep(b_left - softness, b_left + softness, dist_left);
    float mask_right = 1.0 - smoothstep(b_right - softness, b_right + softness, dist_right);
    float mask_top = 1.0 - smoothstep(b_top - softness, b_top + softness, dist_top);
    float mask_bottom = 1.0 - smoothstep(b_bottom - softness, b_bottom + softness, dist_bottom);

    // changed: mask is now purely derived from the four edges; splatter variables and calculations removed
    float mask = max(max(mask_left, mask_right), max(mask_top, mask_bottom));

    float n3 = fbm(pixel_pos * smoke_scale + time_offset3);
    vec4 smoke_mix = mix(fill_color, smoke_color, n3 * smoke_opacity);
    
    float base_alpha = fill_center ? 1.0 : (n3 * smoke_opacity);
    vec4 base = vec4(smoke_mix.rgb, base_alpha);
    
    COLOR = mix(base, border_color, mask);
}