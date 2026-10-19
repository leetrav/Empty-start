/*
God rays — pend00
https://godotshaders.com/shader/god-rays/
Code license: CC0, as declared on the source page.
Godot 4 adaptation: hint_color -> source_color; explicit SCREEN_TEXTURE uniform.
Original algorithm and default parameters retained in the production main menu.
*/
shader_type canvas_item;

uniform float angle = -0.3;
uniform float position = -0.2;
uniform float spread : hint_range(0.0, 1.0) = 0.5;
uniform float cutoff : hint_range(-1.0, 1.0) = 0.1;
uniform float falloff : hint_range(0.0, 1.0) = 0.2;
uniform float edge_fade : hint_range(0.0, 1.0) = 0.15;
uniform float speed = 1.0;
uniform float ray1_density = 8.0;
uniform float ray2_density = 30.0;
uniform float ray2_intensity : hint_range(0.0, 1.0) = 0.3;
uniform vec4 color : source_color = vec4(1.0, 0.9, 0.65, 0.8);
uniform bool hdr = false;
uniform float seed = 5.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// 作者原版程序噪声，无需额外噪声图片。
float random(vec2 uv) {
	return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	float a = random(i);
	float b = random(i + vec2(1.0, 0.0));
	float c = random(i + vec2(0.0, 1.0));
	float d = random(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

mat2 rotate(float a) {
	return mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a)));
}

vec4 screen(vec4 base, vec4 blend) {
	return 1.0 - (1.0 - base) * (1.0 - blend);
}

// 保留作者双层光束、动态噪声与Screen混合方式。
void fragment() {
	vec2 transformed_uv = (rotate(angle) * (UV - position)) / ((UV.y + spread) - UV.y * spread);
	vec2 ray1 = vec2(transformed_uv.x * ray1_density + sin(TIME * 0.1 * speed) * (ray1_density * 0.2) + seed, 1.0);
	vec2 ray2 = vec2(transformed_uv.x * ray2_density + sin(TIME * 0.2 * speed) * (ray1_density * 0.2) + seed, 1.0);
	float cut = step(cutoff, transformed_uv.x) * step(cutoff, 1.0 - transformed_uv.x);
	ray1 *= cut;
	ray2 *= cut;
	float rays;
	if (hdr) {
		rays = noise(ray1) + noise(ray2) * ray2_intensity;
	} else {
		rays = clamp(noise(ray1) + noise(ray2) * ray2_intensity, 0.0, 1.0);
	}
	rays *= smoothstep(0.0, falloff, 1.0 - UV.y);
	rays *= smoothstep(cutoff, edge_fade + cutoff, transformed_uv.x);
	rays *= smoothstep(cutoff, edge_fade + cutoff, 1.0 - transformed_uv.x);
	vec3 shine = screen(texture(SCREEN_TEXTURE, SCREEN_UV), color).rgb;
	COLOR = vec4(shine, rays * color.a);
}
