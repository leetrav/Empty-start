class_name AimReticle
extends Control

@export var reticle_diameter: float = 32.0
@export var center_gap: float = 5.0
@export var line_width: float = 2.0
@export var reticle_color: Color = Color(0.35, 0.95, 0.9, 0.95)

var _mouse_reticle_diameter: float
var _touch_aim_active: bool = false
var _touch_viewport_position: Vector2


# 初始化准心尺寸，并让第一次显示位置与当前鼠标位置对齐。
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mouse_reticle_diameter = reticle_diameter
	size = Vector2.ONE * reticle_diameter
	custom_minimum_size = size
	refresh_mouse_position()
	queue_redraw()


# 鼠标事件只更新显示位置，不拦截同一事件的其他 UI 处理。
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		# 事件位置属于 Viewport；转换到画布后使缩放窗口与注入输入使用同一坐标事实。
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		_touch_aim_active = false
		_set_reticle_diameter(_mouse_reticle_diameter)
		var canvas_position: Vector2 = get_canvas_transform().affine_inverse() * mouse_event.position
		_set_aim_center_global_position(canvas_position)


# 场景布局完成或缩放后重新对齐鼠标，让窗口变化也保持准心中心一致。
func refresh_mouse_position() -> void:
	if _touch_aim_active:
		_set_aim_center_global_position(get_canvas_transform().affine_inverse() * _touch_viewport_position)
		return
	_set_aim_center_global_position(get_global_mouse_position())


# 触屏坐标与鼠标走同一画布变换；显示尺寸和相交判定共用注入的移动端直径。
func move_touch_aim(viewport_position: Vector2, diameter: float) -> void:
	_touch_aim_active = true
	_touch_viewport_position = viewport_position
	_set_reticle_diameter(diameter)
	_set_aim_center_global_position(get_canvas_transform().affine_inverse() * viewport_position)


# 实体鼠标按下时用本次事件坐标恢复 PC 瞄准，避免系统光标读取覆盖有效位置。
func restore_mouse_aim(viewport_position: Vector2) -> void:
	_touch_aim_active = false
	_set_reticle_diameter(_mouse_reticle_diameter)
	_set_aim_center_global_position(get_canvas_transform().affine_inverse() * viewport_position)


# 尺寸改变同步绘制边界，避免触屏仅扩大判定却未扩大显示。
func _set_reticle_diameter(diameter: float) -> void:
	if reticle_diameter == diameter:
		return
	reticle_diameter = diameter
	size = Vector2.ONE * diameter
	custom_minimum_size = size
	queue_redraw()


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
