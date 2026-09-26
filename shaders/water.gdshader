shader_type canvas_item;
// Water spike v3: Beer-Lambert per-channel absorption + vignette.
// God rays are textured cards (god_ray.gdshader), not a fullscreen pattern.

uniform vec4 shallow_color : source_color = vec4(0.10, 0.34, 0.52, 1.0);
uniform vec4 deep_color : source_color = vec4(0.01, 0.05, 0.13, 1.0);
uniform vec3 absorption = vec3(2.8, 1.05, 0.55);
uniform float absorption_strength = 1.8;
uniform float vignette_strength = 0.25;

void fragment() {
	vec2 uv = UV;
	float d = pow(uv.y, 1.25);
	vec3 transmit = exp(-absorption * d * absorption_strength);
	vec3 col = shallow_color.rgb * transmit;
	col += deep_color.rgb * (1.0 - exp(-d * 3.0));
	vec2 vd = uv - vec2(0.5);
	col *= 1.0 - vignette_strength * dot(vd, vd) * 2.0;
	COLOR = vec4(col, 1.0);
}
