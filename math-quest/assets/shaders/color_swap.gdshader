shader_type canvas_item;

// The "tolerance" allows for slight imperfections in the image colors
uniform float tolerance : hint_range(0.0, 1.0) = 0.01;

// Color Pair 1
uniform vec4 color_to_find_1 : source_color;
uniform vec4 replacement_color_1 : source_color;

// Color Pair 2
uniform vec4 color_to_find_2 : source_color;
uniform vec4 replacement_color_2 : source_color;

// Color Pair 3
uniform vec4 color_to_find_3 : source_color;
uniform vec4 replacement_color_3 : source_color;

void fragment() {
    // Read the original pixel color
    vec4 current_color = texture(TEXTURE, UV);

    // Check if the current pixel matches Color 1
    if (distance(current_color.rgb, color_to_find_1.rgb) < tolerance) {
        COLOR = vec4(replacement_color_1.rgb, current_color.a);
    }
    // Check if it matches Color 2
    else if (distance(current_color.rgb, color_to_find_2.rgb) < tolerance) {
        COLOR = vec4(replacement_color_2.rgb, current_color.a);
    }
    // Check if it matches Color 3
    else if (distance(current_color.rgb, color_to_find_3.rgb) < tolerance) {
        COLOR = vec4(replacement_color_3.rgb, current_color.a);
    }
    // If it doesn't match any of our target colors, draw it normally
    else {
        COLOR = current_color;
    }
}