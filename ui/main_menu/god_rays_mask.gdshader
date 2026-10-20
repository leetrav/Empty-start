// pend00 God rays CC0: https://godotshaders.com/shader/god-rays/
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
uniform bool hdr = false;
uniform float seed = 5.0;

// 原版y固定为1，省去二维插值中始终为零的另一行。
float hash(float x) {
 return fract(sin(dot(vec2(x,1.0), vec2(12.9898,78.233)))*43758.5453123);
}
float noise(vec2 uv) {
 float i=floor(uv.x);
 float f=fract(uv.x);
 return mix(hash(i),hash(i+1.0),f*f*(3.0-2.0*f));
}
mat2 rotate(float a) {
	return mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a)));
}

// 保留作者双层光束、动态噪声与Screen混合方式。
uniform float preview_time = -1.0;
void fragment() {
 float clock_time = preview_time < 0.0 ? TIME : preview_time;
	vec2 transformed_uv = (rotate(angle) * (UV - position)) / ((UV.y + spread) - UV.y * spread);
	vec2 ray1 = vec2(transformed_uv.x * ray1_density + sin(clock_time * 0.1 * speed) * (ray1_density * 0.2) + seed, 1.0);
	vec2 ray2 = vec2(transformed_uv.x * ray2_density + sin(clock_time * 0.2 * speed) * (ray1_density * 0.2) + seed, 1.0);
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
	COLOR = vec4(vec3(rays), 1.0);
}
