shader_type canvas_item;
uniform bool hide_zeros = false;
uniform bool isolate_zeros = false;
uniform bool compare_base = false;
uniform sampler2D reference_image;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
varying vec4 vertex_color;
void vertex() { vertex_color = COLOR; }
void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (hide_zeros || isolate_zeros) {
		vec2 p = UV * vec2(1763.0, 979.0);
		bool cut = (p.x < 115.0 && p.y > 355.0 && p.y < 540.0)
		 || (p.x > 265.0 && p.x < 365.0 && p.y > 130.0 && p.y < 275.0)
		 || (p.x > 225.0 && p.x < 330.0 && p.y > 640.0 && p.y < 790.0 && (p.x < 305.0 || p.y < 752.0))
		 || (p.x > 1330.0 && p.x < 1450.0 && p.y < 180.0)
		 || (p.x > 1175.0 && p.x < 1290.0 && p.y > 310.0 && p.y < 480.0)
		 || (p.x > 1550.0 && p.x < 1670.0 && p.y > 565.0 && p.y < 740.0);
		if (hide_zeros && cut) col.a = 0.0;
		if (isolate_zeros && !cut) col.a = 0.0;
	}
	if (compare_base) {
		vec4 original = texture(reference_image, UV);
		col.a *= smoothstep(0.06, 0.18, distance(col.rgb, original.rgb));
	}
	COLOR = col * vertex_color;
}
