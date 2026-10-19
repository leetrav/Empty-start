shader_type canvas_item;
render_mode unshaded;

uniform float strength : hint_range(0.0, 1.0) = 0.66;
uniform vec4 light_color : source_color = vec4(1.0, 0.99, 0.90, 1.0);

// 参考封面的大面积左上角散射光：连续柔和衰减，无扇形条纹。
void fragment() {
	vec2 p = UV - vec2(0.015, -0.045);
	vec2 spread = p / vec2(0.78, 0.68);
	float haze = exp(-dot(spread, spread) * 1.85);
	float source = exp(-dot(p / vec2(0.25, 0.27), p / vec2(0.25, 0.27)) * 1.6);
	float breath = 0.985 + sin(TIME * 0.26) * 0.015;
	float alpha = clamp((haze * 0.86 + source * 0.14) * strength * breath, 0.0, 0.7);
	COLOR = vec4(light_color.rgb, alpha * light_color.a);
}