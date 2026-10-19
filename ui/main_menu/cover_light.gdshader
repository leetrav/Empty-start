shader_type canvas_item;
render_mode unshaded;

uniform float strength : hint_range(0.0, 1.0) = 0.32;

// 左上角暖色柔光和缓慢移动的扇形光束，无额外图片或全屏采样。
void fragment() {
	vec2 p = UV - vec2(0.025, -0.08);
	p.x *= 1.77778;
	float radius = length(p);
	float angle = atan(p.x, p.y);
	float rays = pow(max(0.0, cos(angle * 18.0 + sin(TIME * 0.18) * 0.18)), 7.0);
	float fade = 1.0 - smoothstep(0.0, 1.4, radius);
	float glow = exp(-radius * 3.1);
	float alpha = (glow * 0.65 + rays * fade * 0.24) * strength;
	COLOR = vec4(1.0, 0.98, 0.80, alpha);
}
