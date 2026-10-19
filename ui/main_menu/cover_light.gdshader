shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.95;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.42;
uniform vec4 light_color : source_color = vec4(1.0, 0.93, 0.77, 1.0);
uniform vec2 source_position = vec2(0.015, -0.015);
uniform float dust_strength : hint_range(0.0, 1.0) = 0.22;

float hash_value(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 连续噪声只用于光柱内部的雾感，低速移动，不产生闪烁的硬条纹。
float mist_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_value(cell), hash_value(cell + vec2(1.0, 0.0)), f.x),
		mix(hash_value(cell + vec2(0.0, 1.0)), hash_value(cell + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = (UV - source_position) * vec2(1.77778, 1.0);
	vec2 direction = normalize(vec2(0.92, 0.70));
	float along = dot(p, direction);
	float across = dot(p, vec2(direction.y, -direction.x));
	float width = 0.025 + max(along, 0.0) * 0.12;
	float beam_axis = across / width;
	float envelope = exp(-beam_axis * beam_axis * 1.5);
	float distance_fade = exp(-max(along, 0.0) * 0.45);
	float drift = TIME * 0.025;
	float bands = 0.52 + mist_noise(vec2(beam_axis * 4.0 + drift, 1.8)) * 0.48;
	float haze = 0.75 + mist_noise(vec2(across * 7.0, along * 3.0 - drift)) * 0.25;
	float shaft = envelope * distance_fade * bands * haze;
	float source_glow = exp(-dot(p, p) * 9.0);
	float ambient = exp(-dot(p / vec2(1.1, 0.9), p / vec2(1.1, 0.9)) * 2.4);
	// 稀疏尘埃随空气缓慢上浮，仅在有光的区域显现。
	vec2 dust_uv = UV * vec2(150.0, 84.0) + vec2(TIME * 0.05, -TIME * 0.11);
	vec2 cell = floor(dust_uv);
	vec2 particle_center = vec2(hash_value(cell), hash_value(cell + 11.0)) * 0.6 + 0.2;
	float particle = exp(-dot(fract(dust_uv) - particle_center, fract(dust_uv) - particle_center) * 160.0);
	float dust = particle * step(0.985, hash_value(cell + 23.0)) * envelope * dust_strength;
	// 先建立环境明暗对比，再用柔光柱照亮主体；菜单在本层之后绘制。
	vec3 original = texture(screen_texture, SCREEN_UV).rgb;
	vec2 subject_p = (UV - vec2(0.51, 0.42)) / vec2(0.38, 0.48);
	float subject = exp(-dot(subject_p, subject_p) * 1.5);
	float menu_area = (1.0 - smoothstep(0.25, 0.37, UV.x)) * (1.0 - smoothstep(0.43, 0.55, UV.y));
	menu_area = max(menu_area, (1.0 - smoothstep(0.16, 0.28, UV.x)) * smoothstep(0.74, 0.85, UV.y));
	float lit_area = clamp(max(subject * 1.18, envelope * 0.80), 0.0, 1.0);
	float exposure = mix(1.0 - shadow_strength, 1.02, lit_area);
	exposure = mix(exposure, 0.98, menu_area);
	vec3 shaded = original * vec3(0.94, 0.98, 1.0) * exposure;
	float radiance = clamp((shaft * 0.95 + source_glow * 1.2 + ambient * 0.09) * strength, 0.0, 0.90);
	vec3 illuminated = vec3(1.0) - (vec3(1.0) - shaded) * (vec3(1.0) - light_color.rgb * radiance);
	illuminated += vec3(1.0, 0.91, 0.65) * dust;
	COLOR = vec4(illuminated, 1.0);
}