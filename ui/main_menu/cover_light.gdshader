shader_type canvas_item;
render_mode unshaded;

uniform float strength : hint_range(0.0, 1.5) = 1.10;
uniform vec4 light_color : source_color = vec4(1.0, 0.99, 0.87, 1.0);
uniform vec2 source_position = vec2(-0.035, -0.23);
uniform float beam_width : hint_range(0.1, 0.8) = 0.34;

// 宽光幕覆盖左侧菜单区并落到画面下部，内部光柱层次均为柔边。
void fragment() {
	vec2 p = (UV - source_position) * vec2(1.77778, 1.0);
	vec2 direction = normalize(vec2(0.31, 1.0));
	float along = dot(p, direction);
	float across = dot(p, vec2(direction.y, -direction.x));
	float width = beam_width + max(along, 0.0) * 0.18;
	float q = across / width;
	float envelope = exp(-q * q * 1.50);
	float drift = sin(TIME * 0.23) * 0.035;
	float shafts = exp(-pow((q + 0.52 + drift) / 0.27, 2.0));
	shafts += exp(-pow((q - 0.02 - drift) / 0.30, 2.0));
	shafts += exp(-pow((q - 0.58 + drift) / 0.28, 2.0));
	float distance_fade = 1.0 - smoothstep(0.6, 2.3, along) * 0.32;
	float source_glow = exp(-dot(p, p) * 3.5);
	float breath = 0.985 + sin(TIME * 0.36) * 0.015;
	float alpha = clamp((envelope * (0.39 + shafts * 0.44) * distance_fade + source_glow * 0.20) * strength * breath, 0.0, 0.90);
	COLOR = vec4(light_color.rgb, alpha * light_color.a);
}