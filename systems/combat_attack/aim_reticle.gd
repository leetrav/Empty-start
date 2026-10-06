class_name AimReticle
extends Control

@export var reticle_diameter: float = 32.0
@export var center_gap: float = 5.0
@export var line_width: float = 2.0
@export var reticle_color: Color = Color(0.35, 0.95, 0.9, 0.95)


# 初始化准心尺寸，并让第一次显示位置与当前鼠标位置对齐。
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2.ONE * reticle_diameter
	custom_minimum_size = size
	refresh_mouse_position()
	queue_redraw()


# 鼠标事件只更新显示位置，不拦截同一事件的其他 UI 处理。
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# 事件位置属于 Viewport；转换到画布后使缩放窗口与注入输入使用同一坐标事实。
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		var canvas_position: Vector2 = get_canvas_transform().affine_inverse() * mouse_event.position
		_set_aim_center_global_position(canvas_position)


# 场景布局完成或缩放后重新对齐鼠标，让窗口变化也保持准心中心一致。
func refresh_mouse_position() -> void:
	_set_aim_center_global_position(get_global_mouse_position())


# 中心偏移使用完整缩放基底，避免父级缩放后仍减去未缩放的半径。
func _set_aim_center_global_position(center_position: Vector2) -> void:
	global_position = center_position - get_global_transform().basis_xform(size * 0.5)


# 后续瞄准判定读取这个中心，和准心绘制使用同一几何中心。
func get_aim_center_global_position() -> Vector2:
	return get_global_transform() * (size * 0.5)


# 将目标转回准心设计坐标后判断；绘制和判定一起继承父级的等比或非等比缩放。
func intersects_target_area(target_area: Rect2) -> bool:
	var local_target_area: Rect2 = get_global_transform().affine_inverse() * target_area
	return BarrageAimIntersection.circle_overlaps_rect(
		size * 0.5,
		reticle_diameter,
		local_target_area
	)


# 使用导出的直径和线条配置绘制准心，保留数值表接入前的配置入口。
func _draw() -> void:
	var center: Vector2 = size * 0.5
	var extent: float = reticle_diameter * 0.5
	var inner_edge: float = minf(center_gap, extent)

	draw_line(Vector2(center.x - extent, center.y), Vector2(center.x - inner_edge, center.y), reticle_color, line_width, true)
	draw_line(Vector2(center.x + inner_edge, center.y), Vector2(center.x + extent, center.y), reticle_color, line_width, true)
	draw_line(Vector2(center.x, center.y - extent), Vector2(center.x, center.y - inner_edge), reticle_color, line_width, true)
	draw_line(Vector2(center.x, center.y + inner_edge), Vector2(center.x, center.y + extent), reticle_color, line_width, true)
	draw_circle(center, line_width * 0.75, reticle_color, true)
