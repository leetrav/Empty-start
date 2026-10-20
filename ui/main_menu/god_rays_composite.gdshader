// 保留原版Screen合成，屏幕纹理不生成mipmap。
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;
uniform sampler2D rays_mask : filter_linear, repeat_disable;
uniform vec4 light_color : source_color = vec4(1.0, 0.9, 0.65, 0.8);
void fragment() {
 vec3 base = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
 float rays = texture(rays_mask, UV).r;
 COLOR = vec4(1.0 - (1.0-base)*(1.0-light_color.rgb), rays*light_color.a);
}
