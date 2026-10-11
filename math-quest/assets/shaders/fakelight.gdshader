shader_type canvas_item;
render_mode unshaded; // Removed blend_add to use the default blend_mix

// Added: screen texture to read the pixels currently behind the mesh
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform vec4 light_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float energy = 2.0; // Added: Controls the multiplication strength of the light
uniform float base_luminosity = 0.1; // Added: Ensures the light still shows up even if CanvasModulate is pitch black
uniform float radius = 0.5;
uniform float falloff = 2.0;

void fragment() {
    float dist = distance(UV, vec2(0.5));

    float attenuation = 1.0 - clamp(dist / radius, 0.0, 1.0);
    attenuation = pow(attenuation, falloff);

    // {to-do} Implement noise-based flickering or pulsing

    // Added: Fetch the exact pixel colors of the scene behind this node
    vec3 bg_color = texture(screen_tex, SCREEN_UV).rgb;

    // Added: Multiply the background by the light color to reveal underlying textures naturally,
    // and add a small base luminosity so it doesn't disappear in absolute 0,0,0 darkness.
    vec3 light_calc = (bg_color * light_color.rgb * energy) + (light_color.rgb * base_luminosity);

    // Added: Apply the calculated light using the attenuation gradient as the alpha mask
    COLOR = vec4(light_calc, attenuation * light_color.a);
}