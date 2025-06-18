shader_type spatial;

uniform vec3 top_color : source_color;
uniform vec3 side_color : source_color;

void fragment() {
    // Convert the normal to world space
    vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);

    // Use a strict match for flat top detection
    if (abs(world_normal.y - 1.0) < 0.0001) {
        ALBEDO = top_color;
    } else {
        ALBEDO = side_color;
    }
}