shader_type canvas_item;
render_mode blend_add;
// One god-ray shaft card: soft streak texture, additive, slowly breathing.

uniform sampler2D shaft_tex : filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(0.55, 0.78, 0.92, 1.0);
uniform float intensity = 0.35;
uniform float breathe_speed = 0.15;
uniform float phase = 0.0;

void fragment() {
	float breathe = 0.75 + 0.25 * sin(TIME * breathe_speed + phase);
	vec4 t = texture(shaft_tex, UV);
	vec3 col = tint.rgb * t.a * intensity * breathe;
	COLOR = vec4(col, t.a);
}
