shader_type canvas_item;
// Water spike: depth-graded water column with animated god rays,
// subtle caustic shimmer, and a gentle vignette. The 3D set gets
// built on top of this later.

uniform vec4 shallow_color : source_color = vec4(0.08, 0.30, 0.50, 1.0);
uniform vec4 deep_color : source_color = vec4(0.01, 0.05, 0.13, 1.0);
uniform float ray_intensity = 0.30;
uniform float ray_count = 6.0;
uniform float ray_speed = 0.35;
uniform float shimmer_intensity = 0.04;
uniform float vignette_strength = 0.25;

void fragment() {
	vec2 uv = UV;

	// Depth gradient: teal near the top, deep navy at the bottom.
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, pow(uv.y, 1.25));

	// God rays: slanted bands falling from the surface, animated drift,
	// fading out with depth. Two harmonics so they never look mechanical.
	float slant = uv.x * ray_count + uv.y * 1.6 + TIME * 0.015;
	float r1 = pow(0.5 + 0.5 * sin(slant * 6.28318 + TIME * ray_speed), 4.0);
	float r2 = pow(0.5 + 0.5 * sin(slant * 12.56637 + 1.7 - TIME * ray_speed * 0.6), 6.0);
	float rays = r1 * 0.7 + r2 * 0.3;
	rays *= pow(1.0 - uv.y, 1.8);
	col += vec3(0.45, 0.72, 0.88) * rays * ray_intensity;

	// Caustic shimmer: two interfering waves make a soft dapple (not lines),
	// strongest near the top, fading with depth.
	float c1 = sin(uv.x * 60.0 + TIME * 1.1 + sin(uv.y * 44.0 - TIME * 0.9) * 2.0);
	float c2 = sin((uv.x + uv.y) * 52.0 - TIME * 0.7);
	float c = pow(clamp(c1 * c2 * 0.5 + 0.5, 0.0, 1.0), 6.0);
	c *= shimmer_intensity * (1.0 - uv.y);
	col += vec3(0.40, 0.70, 0.85) * c;

	// Gentle vignette for depth.
	vec2 d = uv - vec2(0.5);
	col *= 1.0 - vignette_strength * dot(d, d) * 2.0;

	COLOR = vec4(col, 1.0);
}
