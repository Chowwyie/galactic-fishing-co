shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Warm sunlit tops, cool teal-gray shadow faces: the concept-art read,
// computed from the world normal so one material serves the whole set.
uniform vec3 top_color : source_color = vec3(0.96, 0.80, 0.58);
uniform vec3 side_color : source_color = vec3(0.36, 0.47, 0.50);
uniform float caustic_strength = 0.12;
uniform float time_scale = 1.0;

varying vec3 wnormal;
varying vec3 wpos;

void vertex() {
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float caustic(vec2 p, float t) {
	vec2 q = p * 0.25;
	float c = sin(q.x * 3.1 + t * 0.7 + sin(q.y * 2.3 - t * 0.5));
	c += sin(q.y * 2.7 - t * 0.6 + sin(q.x * 1.9 + t * 0.4));
	c = c * 0.25 + 0.5;
	return pow(c, 3.0);
}

void fragment() {
	float up = clamp(wnormal.y, 0.0, 1.0);
	float down = clamp(-wnormal.y, 0.0, 1.0);
	float side = 1.0 - abs(wnormal.y);
	vec3 alb = mix(side_color, top_color, smoothstep(0.2, 0.7, up));
	alb = mix(alb, side_color * 0.5, smoothstep(0.2, 0.8, down));
	// Sedimentary strata lines on the side faces.
	float s = fract(wpos.y / 4.0);
	float line = 1.0 - smoothstep(0.0, 0.12, s);
	alb *= 1.0 - line * 0.35 * side;
	// Large-scale tonal variation so faces are not flat.
	float tone = sin(wpos.x * 0.11 + wpos.z * 0.13) * sin(wpos.y * 0.21 + wpos.x * 0.05);
	alb *= 1.0 + tone * 0.05;
	ALBEDO = alb;
	// Caustic shimmer lives on the rock, strongest up-facing and shallow.
	float cmask = smoothstep(0.4, 0.9, up) * exp(-max(30.0 - wpos.y, 0.0) * 0.015);
	float c = caustic(wpos.xz, TIME * time_scale);
	EMISSION = vec3(0.85, 0.95, 1.0) * (c * cmask * caustic_strength);
	ROUGHNESS = 1.0;
}
