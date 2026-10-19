shader_type canvas_item;
render_mode unshaded;

uniform float strength : hint_range(0.0, 1.0) = 0.85;
uniform vec4 light_color : source_color = vec4(1.0, 0.99, 0.85, 1.0);

// 不等宽光束从左上角发散，边缘柔化，避免形成等距细条纹。
float beam(float angle, float center, float width) {
	float distance_to_axis = abs(angle - center) / width;
	return 1.0 - smoothstep(0.55, 1.0, distance_to_axis);
}

// 明确可见的圣光扇面；微弱摇动与呼吸，不改变菜单文字的颜色。
void fragment() {
	vec2 p = UV - vec2(0.035, -0.025);
	p.x *= 1.77778;
	float radius = length(p);
	float angle = atan(p.x, p.y) + sin(TIME * 0.55) * 0.022;
	float rays = beam(angle, 0.10, 0.055);
	rays += beam(angle, 0.32, 0.075);
	rays += beam(angle, 0.60, 0.085);
	rays += beam(angle, 0.91, 0.065);
	rays += beam(angle, 1.18, 0.10);
	float fade = 1.0 - smoothstep(0.28, 1.65, radius);
	float glow = exp(-radius * 4.2);
	float pulse = 0.95 + sin(TIME * 0.7) * 0.05;
	float alpha = clamp((glow * 0.8 + rays * fade * 0.58) * strength * pulse, 0.0, 0.82);
	COLOR = vec4(light_color.rgb, alpha * light_color.a);
}
