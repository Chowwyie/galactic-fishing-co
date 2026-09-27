shader_type spatial;
render_mode specular_disabled, unshaded;

// Faceted 3-step toon ramp for the hill set pieces. The mesh carries flat
// face normals (Blender use_smooth=False), so each facet lands on one step
// of the ramp and reads as a discrete color cell against the pixel-art
// foreground.
//
// Locked key light (view space, direction TO the light): upper-left-front,
// with a soft fill from the right so shadowed facets don't go black.
// Facet deviation is exaggerated (toon-shading emphasis) because the gentle
// hill slopes have subtle normal variation.
//
// Manual exponential fog, lighter than the water's, so the hills read
// through the haze while the far water stays deep.
// Palette: warm sunlit rock -> cool underwater shadow.
uniform vec3 col_light : source_color = vec3(0.96, 0.86, 0.60);
uniform vec3 col_mid : source_color = vec3(0.52, 0.56, 0.44);
uniform vec3 col_dark : source_color = vec3(0.38, 0.42, 0.44);
uniform vec3 light_dir = vec3(-0.45, 0.75, 0.49);
uniform vec3 fill_dir = vec3(0.55, 0.35, 0.76);
uniform float fill_strength = 0.45;
uniform vec3 facet_mean = vec3(0.0, 0.2, 0.98);
uniform float facet_boost = 4.0;
uniform vec3 fog_color : source_color = vec3(0.09, 0.30, 0.48);
uniform float fog_density = 0.005;

varying float v_view_dist;

void vertex() {
	v_view_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 fn = normalize(mix(facet_mean, n, facet_boost));
	float ndl = dot(fn, normalize(light_dir));
	float ndf = dot(fn, normalize(fill_dir)) * fill_strength;
	float lit = max(ndl, ndf);
	vec3 ramp = lit > 0.62 ? col_light : (lit > 0.57 ? col_mid : col_dark);
	float f = 1.0 - exp(-fog_density * v_view_dist);
	ALBEDO = mix(ramp, fog_color, f);
	ROUGHNESS = 1.0;
}
