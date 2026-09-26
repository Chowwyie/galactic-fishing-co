shader_type sky;
// Underwater water volume: Beer-Lambert vertical gradient. Looking up
// (EYEDIR.y -> +1) is the bright surface; looking down is the deep.

uniform vec4 shallow_color : source_color = vec4(0.10, 0.34, 0.52, 1.0);
uniform vec4 deep_color : source_color = vec4(0.01, 0.05, 0.13, 1.0);
uniform vec3 absorption = vec3(2.8, 1.05, 0.55);
uniform float absorption_strength = 1.8;

void sky() {
	float up = clamp(EYEDIR.y * 0.5 + 0.5, 0.0, 1.0);
	float d = pow(1.0 - up, 1.5);
	vec3 transmit = exp(-absorption * d * absorption_strength);
	vec3 col = shallow_color.rgb * transmit;
	col += deep_color.rgb * (1.0 - exp(-d * 3.0));
	float glow = pow(max(EYEDIR.y, 0.0), 3.0);
	col += vec3(0.45, 0.70, 0.88) * glow * 0.5;
	COLOR = col;
}
