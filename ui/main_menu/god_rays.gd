extends ColorRect
# 光束强度在小纹理计算，正式画面仍按原版Screen公式合成。
var mask_viewport: SubViewport
var mask_material: ShaderMaterial
func _ready() -> void:
	mask_viewport = SubViewport.new()
	mask_viewport.name = "RaysMask"
	mask_viewport.disable_3d = true
	mask_viewport.transparent_bg = false
	add_child(mask_viewport)
	var mask := ColorRect.new()
	mask.size = Vector2(1920,1080)
	mask_material = ShaderMaterial.new()
	mask_material.shader = preload("res://ui/main_menu/god_rays_mask.gdshader")
	mask.material = mask_material
	mask_viewport.add_child(mask)
	var composite := ShaderMaterial.new()
	composite.shader = preload("res://ui/main_menu/god_rays_composite.gdshader")
	composite.set_shader_parameter("rays_mask", mask_viewport.get_texture())
	material = composite
	SettingsManager.menu_rays_quality_changed.connect(set_quality)
	set_quality(SettingsManager.menu_rays_quality)
# 0关闭时同时停止离屏绘制；1低档/2标准只降低光效，不降低菜单美术分辨率。
func set_quality(quality: int) -> void:
	visible = quality > 0
	mask_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if quality > 0 else SubViewport.UPDATE_DISABLED
	mask_viewport.size = Vector2i(480,270) if quality == 1 else Vector2i(960,540)
	(mask_viewport.get_child(0) as ColorRect).size = Vector2(mask_viewport.size)
