shader_type canvas_item;
// Water spike: Beer-Lambert absorption + noise-broken procedural god rays.
// The ray field is domain-warped and intensity-churned by fbm noise so the
// shafts are uneven, feathered, and never read as perfect bands.
// (Textured ray cards come with the 3D set, where they have geometry.)

uniform vec4 shallow_color : source_color = vec4(0.10, 0.34, 0.52, 1.0);
uniform vec4 deep_color : source_color = vec4(0.01, 0.05, 0.13, 1.0);
uniform vec3 absorption = vec3(2.8, 1.05, 0.55);
uniform float absorption_strength = 1.8;
uniform float ray_intensity = 0.26;
uniform float ray_count = 6.0;
uniform float ray_speed = 0.35;
uniform float vignette_strength = 0.25;

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
	float d = pow(uv.y, 1.25);

	vec3 transmit = exp(-absorption * d * absorption_strength);
	vec3 col = shallow_color.rgb * transmit;
	col += deep_color.rgb * (1.0 - exp(-d * 3.0));

	// Warp the ray domain with slow noise: bands become unevenly spaced
	// and their edges undulate instead of running straight.
	float warp = fbm(vec2(uv.x * 2.0, uv.y * 1.2) + vec2(TIME * 0.03, TIME * 0.012));
	float slant = (uv.x + (warp - 0.5) * 0.35) * ray_count + uv.y * 1.6;
	float band = pow(0.5 + 0.5 * sin(slant * 6.28318 + TIME * ray_speed), 3.0);
	// Churn the brightness along each shaft with scrolling noise so the
	// light evolves instead of translating rigidly.
	float churn = fbm(vec2(uv.x * 3.0 + 7.0, uv.y * 1.8 - TIME * 0.07));
	float rays = band * smoothstep(0.15, 0.75, churn) * pow(1.0 - uv.y, 1.8);
	col += vec3(0.55, 0.78, 0.92) * rays * ray_intensity;

	vec2 vd = uv - vec2(0.5);
	col *= 1.0 - vignette_strength * dot(vd, vd) * 2.0;

	COLOR = vec4(col, 1.0);
}
