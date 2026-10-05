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
	_update_mouse_position()
	queue_redraw()


# 鼠标事件只更新显示位置，不拦截同一事件的其他 UI 处理。
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_mouse_position()


# 显示节点左上角偏移半个准心尺寸，使准心视觉中心与鼠标坐标重合。
func _update_mouse_position() -> void:
	global_position = get_global_mouse_position() - size * 0.5


# 后续瞄准判定读取这个中心，和准心绘制使用同一几何中心。
func get_aim_center_global_position() -> Vector2:
	return global_position + size * 0.5


# 复用准心当前配置尺寸判断弹幕区域，不在攻击系统复制判定常量。
func intersects_target_area(target_area: Rect2) -> bool:
	return BarrageAimIntersection.circle_overlaps_rect(
		get_aim_center_global_position(),
		reticle_diameter,
		target_area
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
