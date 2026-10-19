shader_type canvas_item;
render_mode unshaded;

uniform float strength : hint_range(0.0, 1.0) = 0.90;
uniform vec4 light_color : source_color = vec4(1.0, 0.99, 0.88, 1.0);
uniform vec2 source_position = vec2(-0.025, -0.08);
uniform vec2 pointing_position = vec2(0.29, 0.39);
uniform float beam_width : hint_range(0.05, 0.5) = 0.22;

// 一整束宽光从左上方落向仓鼠指尖区域，柔边收束，不穿过整只仓鼠。
void fragment() {
	vec2 aspect = vec2(1.77778, 1.0);
	vec2 target = (pointing_position - source_position) * aspect;
	vec2 direction = normalize(target);
	vec2 p = (UV - source_position) * aspect;
	float along = dot(p, direction);
	float across = dot(p, vec2(direction.y, -direction.x));
	float target_distance = length(target);
	float width = 0.075 + max(along, 0.0) * beam_width;
	float envelope = exp(-pow(across / width, 2.0) * 1.6);
	float end_fade = 1.0 - smoothstep(target_distance * 0.93, target_distance * 1.50, along);
	float core = envelope * end_fade;
	float source_glow = exp(-dot(p, p) * 5.0);
	float breath = 0.985 + sin(TIME * 0.45) * 0.015;
	float alpha = clamp((core * 0.94 + source_glow * 0.18) * strength * breath, 0.0, 0.88);
	COLOR = vec4(light_color.rgb, alpha * light_color.a);
}