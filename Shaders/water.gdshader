shader_type spatial;
render_mode unshaded;

uniform vec4 water_color : source_color = vec4(0.2, 0.4, 0.9, 1.0);
uniform vec4 foam_color : source_color = vec4(0.9, 0.9, 1.0, 1.0);

uniform sampler2D noise_text: filter_linear;
uniform sampler2D distortion_text: filter_linear;

uniform float noise_intensity = 0.9;
uniform float distortion_intensity = 0.7;

uniform float foam_threshold = 0.5;
uniform float border_width = 0.15;

uniform float time_speed = 0.5;

void fragment() {
    float t = TIME * time_speed;
	float distortion_val = texture(distortion_text, UV + vec2(0.1, 0.1) * t).r * distortion_intensity;
	float noise_val = texture(noise_text, UV + vec2(0.05, 0.05) * t + distortion_val).r * noise_intensity;

    float edge_distance = smoothstep(border_width, 0.0, UV2.x);;

	float noise_cutoff = foam_threshold * (1.0-edge_distance);
    float foam = noise_val > noise_cutoff ? 1.0 : 0.0;

    vec4 color = water_color + foam * foam_color;
    ALBEDO = color.rgb;
}