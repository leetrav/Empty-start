class_name ComicEffects
extends Node

const CUTOUT = preload("res://ui/comic/comic_cutout.gdshader")
const GLOW = preload("res://ui/comic/comic_glow.gdshader")
var _frame: ComicFrame
var _canvas: Control
var _layers: Array[TextureRect]
var _overlays: Array[Control] = []
var _origins: Array[Vector2] = []
var _time: float = 0.0
var _glow: ColorRect
var paused: bool = false

# 所有动态拆层仅运行时构建，原图不裁写；结束时统一销毁。
func setup(frame: ComicFrame, canvas: Control, layers: Array[TextureRect]) -> void:
	_frame = frame
	_canvas = canvas
	_layers = layers
	if frame.effect == "zeros":
		var material := ShaderMaterial.new()
		material.shader = CUTOUT
		material.set_shader_parameter("hide_zeros", true)
		_layers[1].material = material
		var regions: Array[Rect2] = [Rect2(0,355,115,185),Rect2(265,130,100,145),Rect2(225,640,105,150),Rect2(1330,0,120,180),Rect2(1175,310,115,170),Rect2(1550,565,120,175)]
		for region in regions:
			var zero := _add_region(frame.textures[1], region, frame.positions[1] + region.position)
			var zero_material := ShaderMaterial.new()
			zero_material.shader = CUTOUT
			zero_material.set_shader_parameter("isolate_zeros", true)
			zero.get_child(0).material = zero_material
	elif frame.effect == "halo":
		_glow = ColorRect.new()
		_glow.position = Vector2(480,70)
		_glow.size = Vector2(950,970)
		_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var glow_material := ShaderMaterial.new()
		glow_material.shader = GLOW
		_glow.material = glow_material
		canvas.add_child(_glow)
		var image := preload("res://assets/manga/P4/最终效果.png")
		var regions: Array[Rect2] = [Rect2(35,45,800,225),Rect2(1270,255,650,225),Rect2(0,510,670,245),Rect2(1150,835,770,245)]
		for region in regions:
			if _frame.captions.is_empty() or _frame.captions[0].kind != "danmaku":
				break
			var control := _add_region(image, region, region.position)
			var panel_material := ShaderMaterial.new()
			panel_material.shader = CUTOUT
			panel_material.set_shader_parameter("compare_base", true)
			panel_material.set_shader_parameter("reference_image", frame.textures[0])
			control.get_child(0).material = panel_material

# 使用裁剪容器显示原图局部，可独立移动且不更改交付素材。
func _add_region(texture: Texture2D, region: Rect2, origin: Vector2) -> Control:
	var crop := Control.new()
	crop.size = region.size
	crop.position = origin
	crop.clip_contents = true
	crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := TextureRect.new()
	image.texture = texture
	image.position = -region.position
	image.size = texture.get_size()
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crop.add_child(image)
	_canvas.add_child(crop)
	_overlays.append(crop)
	_origins.append(origin)
	return crop

# 小幅角色抖动与弹幕漂浮独立于镜头；每帧从原位置计算，避免累积漂移。
func _process(delta: float) -> void:
	if paused or _frame == null:
		return
	_time += delta
	var t := maxf(0.0, _time - _frame.reveal_seconds)
	if _frame.effect == "tremble" and t > 0 and _frame.effect_layer >= 0:
		var weight := maxf(0, 1.0 - t / 1.4)
		_layers[_frame.effect_layer].position = _frame.positions[_frame.effect_layer] + Vector2(sin(t * 95) * 10, sin(t * 67) * 2) * weight
	elif _frame.effect == "impact" and t > 0:
		var weight := maxf(0, 1.0 - t / 0.35)
		for i in range(_layers.size()):
			_layers[i].position = _frame.positions[i] + Vector2(sin(t * 110) * 13, cos(t * 83) * 5) * weight
	elif _frame.effect == "push" and t > 0 and _frame.effect_layer >= 0:
		var layer := _layers[_frame.effect_layer]
		layer.pivot_offset = layer.size * 0.5
		layer.scale = Vector2.ONE * (1.0 + minf(t / 2.5,1.0) * 0.025)
	for i in range(_overlays.size()):
		var overlay := _overlays[i]
		if _frame.effect == "zeros":
			overlay.position = _origins[i] + Vector2(sin(_time * 1.3 + i) * 3, sin(_time * 2.0 + i * 1.1) * 12)
			overlay.modulate.a = minf(_time / 0.45, 1.0)
		elif _frame.effect == "halo":
			var age := maxf(0, _time - 0.3 - i * 0.28)
			var side := -1 if i % 2 == 0 else 1
			overlay.position = _origins[i] + Vector2(side * 85 * maxf(0, 1.0 - age / 0.6), sin(_time * 1.6 + i) * 5)
			overlay.modulate.a = clampf(age / 0.55, 0.0, 1.0)
	if is_instance_valid(_glow):
		_glow.modulate.a = minf(_time / 0.8, 1.0) * (0.65 + sin(_time * 2) * 0.12)

# 切帧、快进、退出都恢复源层，再移除运行时特效。
func clear() -> void:
	for i in range(_layers.size()):
		if is_instance_valid(_layers[i]):
			_layers[i].position = _frame.positions[i]
			_layers[i].scale = Vector2.ONE
			_layers[i].pivot_offset = Vector2.ZERO
			_layers[i].material = null
	for node in _overlays:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	if is_instance_valid(_glow):
		_glow.get_parent().remove_child(_glow)
		_glow.queue_free()
	set_process(false)

# 文字跟随对应弹幕框，宿主只读取位移，不持有内部裁剪节点。
func get_danmaku_offset(index: int) -> Vector2:
	if _frame.effect != "halo" or index < 0 or index >= _overlays.size():
		return Vector2.ZERO
	return _overlays[index].position - _origins[index]
