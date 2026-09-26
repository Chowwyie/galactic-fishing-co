shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// A god-ray shaft as a 3D quad: bright core with diffuse falloff, vertical
// fade, and fbm noise breakup so edges are wispy and light churns slowly.

uniform vec4 tint : source_color = vec4(0.55, 0.78, 0.92, 1.0);
uniform float intensity = 0.45;
uniform float seed = 0.0;

float hash(vec2 p) {
	vec2 q = fract(p * vec2(123.34, 456.21));
	q += dot(q, q + 45.32);
	return fract(q.x * q.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float across = 1.0 - abs(uv.x - 0.5) * 2.0;
	across = pow(max(across, 0.0), 1.8);
	// Bright through the upper shaft, fading down; also faded right at the
	// top edge so no hard source line is ever visible.
	float down = pow(1.0 - uv.y, 1.4) * smoothstep(0.0, 0.18, uv.y);
	float n = fbm(vec2(uv.x * 3.0 + seed, uv.y * 2.5 - TIME * 0.05));
	float edge = fbm(vec2(uv.x * 7.0 - seed, uv.y * 5.0 + TIME * 0.04));
	float body = across * down * (0.5 + 0.5 * n) * smoothstep(0.1, 0.55, edge + across * 0.45);
	ALBEDO = tint.rgb * intensity;
	ALPHA = body;
}
