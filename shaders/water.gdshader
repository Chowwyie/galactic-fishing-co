shader_type canvas_item;
// Water spike v2: Beer-Lambert per-channel absorption (red dies first),
// animated god rays, vignette. Caustics live on the 3D set, not here.

uniform vec4 shallow_color : source_color = vec4(0.10, 0.34, 0.52, 1.0);
uniform vec4 deep_color : source_color = vec4(0.01, 0.05, 0.13, 1.0);
uniform vec3 absorption = vec3(2.8, 1.05, 0.55);
uniform float absorption_strength = 1.8;
uniform float ray_intensity = 0.26;
uniform float ray_count = 6.0;
uniform float ray_speed = 0.35;
uniform float vignette_strength = 0.25;

void fragment() {
	vec2 uv = UV;
	float d = pow(uv.y, 1.25);

	vec3 transmit = exp(-absorption * d * absorption_strength);
	vec3 col = shallow_color.rgb * transmit;
	col += deep_color.rgb * (1.0 - exp(-d * 3.0));

	float slant = uv.x * ray_count + uv.y * 1.6 + TIME * 0.015;
	float r1 = pow(0.5 + 0.5 * sin(slant * 6.28318 + TIME * ray_speed), 4.0);
	float r2 = pow(0.5 + 0.5 * sin(slant * 12.56637 + 1.7 - TIME * ray_speed * 0.6), 6.0);
	float rays = (r1 * 0.7 + r2 * 0.3) * pow(1.0 - uv.y, 1.8);
	col += vec3(0.45, 0.72, 0.88) * rays * ray_intensity;

	vec2 vd = uv - vec2(0.5);
	col *= 1.0 - vignette_strength * dot(vd, vd) * 2.0;

	COLOR = vec4(col, 1.0);
}
