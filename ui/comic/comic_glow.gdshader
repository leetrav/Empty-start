shader_type canvas_item;
render_mode blend_add;
uniform float strength = 0.22;
void fragment() {
	float d = length((UV - vec2(0.5)) * vec2(1.0, 0.85));
	float ring = exp(-pow((d - 0.33) * 15.0, 2.0)) * (1.0 - smoothstep(0.42, 0.5, d));
	COLOR = vec4(1.0, 0.68, 0.22, ring * strength * COLOR.a);
}
