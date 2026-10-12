## Paradox 转场与结果漫画字；父场景负责何时播放及消费完成通知。
class_name ParadoxComicTransition
extends Control

signal transition_finished
signal result_feedback_finished(success: bool)

enum PlaybackMode { IDLE, TRANSITION, RESULT }

@export_group("分镜时间（秒）")
@export_range(0.0, 2.0, 0.05) var silence_seconds: float = 0.7
@export_range(0.1, 2.0, 0.05) var slash_seconds: float = 0.6
@export_range(0.1, 2.0, 0.05) var title_pop_seconds: float = 0.35
@export_range(0.0, 3.0, 0.05) var title_hold_seconds: float = 0.95
@export_range(0.1, 3.0, 0.05) var reveal_seconds: float = 1.0
@export_range(0.05, 1.0, 0.01) var flash_seconds: float = 0.16
@export_range(0.1, 2.0, 0.05) var result_feedback_seconds: float = 0.75

@export_group("双斜切与闪白")
@export_range(-45.0, 45.0, 1.0) var slash_angle_degrees: float = -13.0
@export_range(24.0, 180.0, 2.0) var slash_width: float = 94.0
@export_range(0.0, 64.0, 1.0) var slash_edge_jaggedness: float = 16.0
@export_range(0.0, 1.0, 0.01) var dim_alpha: float = 0.82
@export_range(0.0, 1.0, 0.01) var flash_alpha: float = 0.94
@export_range(6, 64, 1) var shock_line_count: int = 30
@export_range(0.0, 48.0, 1.0) var reveal_edge_jaggedness: float = 24.0
@export var dim_color: Color = Color("#11151D")
@export var ink_color: Color = Color("#17191F")
@export var paper_color: Color = Color("#FFF2D5")
@export var accent_color: Color = Color("#D84A46")

@export_group("标题与结果字")
@export var title_font: Font
@export var title_text: String = "矛盾击破！"
@export var breakthrough_text: String = "击破！"
@export var unbroken_text: String = "未击破"
@export_range(48, 132, 1) var title_font_size: int = 88
@export_range(1, 28, 1) var title_outline_size: int = 14
@export var title_color: Color = Color("#FFF6E7")
@export var title_outline_color: Color = Color("#17191F")
@export var title_shadow_color: Color = Color("#A92F3E")
@export var breakthrough_color: Color = Color("#FFE6A1")
@export var unbroken_color: Color = Color("#FFD7D1")

var _mode: PlaybackMode = PlaybackMode.IDLE
var _elapsed: float = 0.0
var _result_success: bool = false

@onready var _title_shadow: Label = $TitleShadow
@onready var _title: Label = $Title


# 初始化绘制层并监听尺寸变化。
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	resized.connect(_on_resized)
	call_deferred("_on_resized")
	visible = false

# 跟进转场时序并在到点后发出表现完成通知。
func _process(delta: float) -> void:
	if _mode == PlaybackMode.IDLE:
		return
	_elapsed += delta
	_update_title_pose()
	queue_redraw()
	if _mode == PlaybackMode.TRANSITION and _elapsed >= _transition_duration():
		_mode = PlaybackMode.IDLE
		visible = false
		transition_finished.emit()
	elif _mode == PlaybackMode.RESULT and _elapsed >= result_feedback_seconds:
		_mode = PlaybackMode.IDLE
		visible = false
		result_feedback_finished.emit(_result_success)


## 从空场开始完整播放斜切、撞击字和撕幕；完成后由组合方开始可操作窗口。
func play_transition() -> void:
	_elapsed = 0.0
	_mode = PlaybackMode.TRANSITION
	_title.text = title_text
	_title_shadow.text = title_text
	_apply_title_style(title_color)
	_raise_above_siblings()
	visible = true
	_update_title_pose()
	queue_redraw()


## 显示本场矛盾结果漫画字，完成信号可交回既有后续流程。
func play_result_feedback(success: bool) -> void:
	_elapsed = 0.0
	_result_success = success
	_mode = PlaybackMode.RESULT
	_title.text = breakthrough_text if success else unbroken_text
	_title_shadow.text = _title.text
	_apply_title_style(breakthrough_color if success else unbroken_color)
	_raise_above_siblings()
	visible = true
	_update_title_pose()
	queue_redraw()


## 重开或中断时立即收起全部遮罩与文案，不广播完成事件。
func reset_for_attempt() -> void:
	_elapsed = 0.0
	_mode = PlaybackMode.IDLE
	visible = false
	_title.visible = false
	_title_shadow.visible = false
	queue_redraw()


# 按播放状态重绘全屏图形效果。
func _draw() -> void:
	if _mode == PlaybackMode.TRANSITION:
		_draw_transition()
	elif _mode == PlaybackMode.RESULT:
		_draw_result_feedback()


# 绘制压暗、交叉斜切、闪白和中间撕幕。
func _draw_transition() -> void:
	var center: Vector2 = size * 0.5
	var dim_progress: float = _ease_out(clampf(_elapsed / maxf(silence_seconds, 0.001), 0.0, 1.0))
	var dim: Color = dim_color
	dim.a = dim_alpha * dim_progress
	draw_rect(Rect2(Vector2.ZERO, size), dim)

	var slash_start: float = silence_seconds
	var slash_progress: float = clampf((_elapsed - slash_start) / maxf(slash_seconds, 0.001), 0.0, 1.0)
	if slash_progress > 0.0 and _elapsed < _reveal_start_time():
		var eased_progress: float = _ease_out(slash_progress)
		var travel: float = size.length() * 0.52
		var first_tangent: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(slash_angle_degrees)).normalized()
		var second_tangent: Vector2 = Vector2.LEFT.rotated(deg_to_rad(slash_angle_degrees)).normalized()
		_draw_slash_band(first_tangent, first_tangent.orthogonal(), lerpf(-travel, 0.0, eased_progress))
		_draw_slash_band(second_tangent, second_tangent.orthogonal(), lerpf(travel, 0.0, eased_progress))

	var impact_time: float = slash_start + slash_seconds
	var impact_elapsed: float = _elapsed - impact_time
	if impact_elapsed >= 0.0 and impact_elapsed < flash_seconds:
		var flash_progress: float = impact_elapsed / maxf(flash_seconds, 0.001)
		var flash: Color = paper_color
		flash.a = flash_alpha * (1.0 - flash_progress) * (1.0 - flash_progress)
		draw_rect(Rect2(Vector2.ZERO, size), flash)
		_draw_shock_lines(center, 1.0 - flash_progress)

	if _elapsed >= _reveal_start_time():
		_draw_opening_curtains(_ease_out(clampf((_elapsed - _reveal_start_time()) / maxf(reveal_seconds, 0.001), 0.0, 1.0)))


# 使用三层色带形成有粗边、红切边和拖影的漫画斜切。
func _draw_slash_band(tangent: Vector2, normal: Vector2, travel: float) -> void:
	for trail_index: int in range(2, 0, -1):
		var trail_color: Color = accent_color if trail_index == 1 else paper_color
		trail_color.a = 0.19 / float(trail_index)
		var trail_points: PackedVector2Array = _make_slash_polygon(
			tangent, normal, travel + float(trail_index) * 34.0, slash_width * 0.55
		)
		draw_colored_polygon(trail_points, trail_color)

	var outer: PackedVector2Array = _make_slash_polygon(tangent, normal, travel, slash_width + 14.0)
	var red_edge: PackedVector2Array = _make_slash_polygon(tangent, normal, travel + 2.0, slash_width + 2.0)
	var paper: PackedVector2Array = _make_slash_polygon(tangent, normal, travel - 1.0, slash_width - 14.0)
	draw_colored_polygon(outer, ink_color)
	draw_colored_polygon(red_edge, accent_color)
	draw_colored_polygon(paper, paper_color)
	draw_polyline(outer, ink_color, 5.0, true)


# 沿斜线采样不规则边缘，返回闭合色带轮廓。
func _make_slash_polygon(tangent: Vector2, normal: Vector2, travel: float, width: float) -> PackedVector2Array:
	var leading_edge := PackedVector2Array()
	var trailing_edge := PackedVector2Array()
	var center: Vector2 = size * 0.5
	var half_length: float = size.length() * 0.825
	const SEGMENTS: int = 14
	for index: int in range(SEGMENTS + 1):
		var along: float = lerpf(-half_length, half_length, float(index) / float(SEGMENTS))
		var uneven_a: float = sin(float(index) * 2.31) * slash_edge_jaggedness
		var uneven_b: float = cos(float(index) * 1.73) * slash_edge_jaggedness
		var point: Vector2 = center + tangent * along + normal * travel
		leading_edge.append(point + normal * (-width * 0.5 + uneven_a))
		trailing_edge.append(point + normal * (width * 0.5 + uneven_b))
	var polygon: PackedVector2Array = leading_edge
	for index: int in range(trailing_edge.size() - 1, -1, -1):
		polygon.append(trailing_edge[index])
	polygon.append(polygon[0])
	return polygon


# 在交叉中心绘制随闪白衰减的放射冲击线。
func _draw_shock_lines(center: Vector2, strength: float) -> void:
	var ray_color: Color = ink_color
	ray_color.a = strength
	var light_color: Color = paper_color
	light_color.a = strength * 0.8
	var base_radius: float = minf(size.x, size.y) * 0.11
	var reach: float = size.length() * 0.38
	for index: int in range(shock_line_count):
		var angle: float = TAU * float(index) / float(shock_line_count) + deg_to_rad(slash_angle_degrees)
		var direction: Vector2 = Vector2.RIGHT.rotated(angle)
		var start: Vector2 = center + direction * base_radius
		var finish: Vector2 = center + direction * reach
		draw_line(start, finish, ray_color if index % 2 == 0 else light_color, 3.0 if index % 2 == 0 else 1.5, true)


# 两侧斜撕幕按进度向画布外拉开。
func _draw_opening_curtains(progress: float) -> void:
	var opening: float = (size.x * 0.5 + 64.0) * progress
	_draw_curtain_panel(-1, opening, paper_color)
	_draw_curtain_panel(1, opening, accent_color)


# 将锯齿撕边拆为凸四边形，避免凹多边形三角化失效。
func _draw_curtain_panel(side: int, opening: float, panel_color: Color) -> void:
	const SEGMENTS: int = 14
	for index: int in range(SEGMENTS):
		var y0: float = size.y * float(index) / float(SEGMENTS)
		var y1: float = size.y * float(index + 1) / float(SEGMENTS)
		var seam_base: float = size.x * 0.5 + float(side) * opening
		var seam0: float = seam_base + sin(float(index) * 2.14) * reveal_edge_jaggedness
		var seam1: float = seam_base + sin(float(index + 1) * 2.14) * reveal_edge_jaggedness
		var x0: float = clampf(seam0, 0.0, size.x)
		var x1: float = clampf(seam1, 0.0, size.x)
		if (side < 0 and maxf(seam0, seam1) <= 0.5) or (side > 0 and minf(seam0, seam1) >= size.x - 0.5):
			continue

		var polygon := PackedVector2Array()
		if side < 0:
			if seam0 <= 0.5:
				polygon = PackedVector2Array([Vector2(0.0, y0), Vector2(x1, y1), Vector2(0.0, y1)])
			elif seam1 <= 0.5:
				polygon = PackedVector2Array([Vector2(0.0, y0), Vector2(x0, y0), Vector2(0.0, y1)])
			else:
				polygon = PackedVector2Array([Vector2(0.0, y0), Vector2(x0, y0), Vector2(x1, y1), Vector2(0.0, y1)])
		else:
			if seam0 >= size.x - 0.5:
				polygon = PackedVector2Array([Vector2(size.x, y0), Vector2(size.x, y1), Vector2(x1, y1)])
			elif seam1 >= size.x - 0.5:
				polygon = PackedVector2Array([Vector2(x0, y0), Vector2(size.x, y0), Vector2(size.x, y1)])
			else:
				polygon = PackedVector2Array([Vector2(x0, y0), Vector2(size.x, y0), Vector2(size.x, y1), Vector2(x1, y1)])

		var shadow_points: PackedVector2Array = polygon.duplicate()
		for point_index: int in range(shadow_points.size()):
			shadow_points[point_index] += Vector2(float(side) * 10.0, 7.0)
		var shadow: Color = ink_color
		shadow.a = 0.9
		draw_colored_polygon(shadow_points, shadow)
		draw_colored_polygon(polygon, panel_color)
		var seam_start: Vector2 = Vector2(x0, y0)
		var seam_end: Vector2 = Vector2(x1, y1)
		draw_line(seam_start, seam_end, ink_color, 12.0, true)
		var torn_accent: Color = accent_color if side < 0 else paper_color
		draw_line(seam_start, seam_end, torn_accent, 5.0, true)


# 绘制短暂压暗、结果爆点和结果字背景。
func _draw_result_feedback() -> void:
	var fade: float = 1.0 - clampf(_elapsed / maxf(result_feedback_seconds, 0.001), 0.0, 1.0)
	var shade: Color = dim_color
	shade.a = 0.84 * fade
	draw_rect(Rect2(Vector2.ZERO, size), shade)
	var center: Vector2 = size * 0.5
	_draw_result_burst(center, fade)
	var flash_progress: float = clampf(_elapsed / maxf(flash_seconds, 0.001), 0.0, 1.0)
	if _elapsed < flash_seconds:
		var flash: Color = paper_color
		flash.a = flash_alpha * (1.0 - flash_progress)
		draw_rect(Rect2(Vector2.ZERO, size), flash)


# 按成败使用不同颜色绘制硬边漫画爆点。
func _draw_result_burst(center: Vector2, strength: float) -> void:
	var burst_points := PackedVector2Array()
	var inner_radius: float = minf(size.x, size.y) * 0.12
	var outer_radius: float = minf(size.x, size.y) * 0.32
	const POINTS: int = 36
	for index: int in range(POINTS):
		var alternating: float = outer_radius if index % 2 == 0 else inner_radius
		var angle: float = TAU * float(index) / float(POINTS) - PI * 0.5
		burst_points.append(center + Vector2.RIGHT.rotated(angle) * alternating)
	burst_points.append(burst_points[0])
	var burst_color: Color = accent_color if not _result_success else Color("#B47A28")
	burst_color.a = 0.94 * strength
	draw_colored_polygon(burst_points, burst_color)
	draw_polyline(burst_points, ink_color, 8.0, true)


# 按分镜时间驱动标题过冲、回弹、上移与淡出。
func _update_title_pose() -> void:
	if not is_node_ready():
		return
	var show_title: bool = _mode == PlaybackMode.RESULT
	var title_start: float = silence_seconds + slash_seconds
	var reveal_start: float = _reveal_start_time()
	var alpha: float = 1.0
	var scale_amount: float = 1.0
	var lift: float = 0.0
	var rotation: float = -3.5
	if _mode == PlaybackMode.TRANSITION:
		show_title = _elapsed >= title_start
		if show_title:
			var pop: float = clampf((_elapsed - title_start) / maxf(title_pop_seconds, 0.001), 0.0, 1.0)
			if pop < 0.58:
				scale_amount = lerpf(0.68, 1.18, _ease_out_back(pop / 0.58))
			else:
				scale_amount = lerpf(1.18, 1.0, _ease_out((pop - 0.58) / 0.42))
			if _elapsed >= reveal_start:
				var reveal: float = _ease_out(clampf((_elapsed - reveal_start) / maxf(reveal_seconds, 0.001), 0.0, 1.0))
				lift = -size.y * 0.22 * reveal
				alpha = 1.0 - reveal
				scale_amount = lerpf(scale_amount, 0.72, reveal)
				rotation = lerpf(rotation, 0.0, reveal)
	elif _mode == PlaybackMode.RESULT:
		var pop: float = clampf(_elapsed / maxf(flash_seconds * 1.8, 0.001), 0.0, 1.0)
		if pop < 0.65:
			scale_amount = lerpf(0.65, 1.12, _ease_out_back(pop / 0.65))
		else:
			scale_amount = lerpf(1.12, 1.0, _ease_out((pop - 0.65) / 0.35))
		alpha = 1.0 - clampf((_elapsed - result_feedback_seconds * 0.62) / maxf(result_feedback_seconds * 0.38, 0.001), 0.0, 1.0)

	_title.visible = show_title
	_title_shadow.visible = show_title
	if not show_title:
		return
	var title_position: Vector2 = Vector2(36.0, (size.y - 200.0) * 0.5 + lift)
	var title_size: Vector2 = Vector2(size.x - 72.0, 200.0)
	_title.position = title_position
	_title_shadow.position = title_position + Vector2(10.0, 12.0)
	_title.size = title_size
	_title_shadow.size = title_size
	_title.pivot_offset = title_size * 0.5
	_title_shadow.pivot_offset = title_size * 0.5
	_title.scale = Vector2.ONE * scale_amount
	_title_shadow.scale = Vector2.ONE * scale_amount
	_title.rotation_degrees = rotation
	_title_shadow.rotation_degrees = rotation
	_title.modulate = Color(1.0, 1.0, 1.0, alpha)
	_title_shadow.modulate = Color(1.0, 1.0, 1.0, alpha)


# 在 Inspector 字体入口基础上应用描边、偏移影和字号。
func _apply_title_style(font_color: Color) -> void:
	if not is_node_ready():
		return
	for label: Label in [_title_shadow, _title]:
		label.add_theme_font_size_override("font_size", title_font_size)
		label.add_theme_constant_override("outline_size", title_outline_size)
		label.add_theme_color_override("font_outline_color", title_outline_color)
		if title_font != null:
			label.add_theme_font_override("font", title_font)
	_title.add_theme_color_override("font_color", font_color)
	_title_shadow.add_theme_color_override("font_color", title_shadow_color)


# 尺寸改变时刷新局部几何与标题布局。
func _on_resized() -> void:
	queue_redraw()
	_update_title_pose()


# 同画布层可能新添高层弹幕；把漫画层移到兄弟节点末尾覆盖结果画面。
func _raise_above_siblings() -> void:
	var layer_parent: Node = get_parent()
	if layer_parent != null:
		layer_parent.move_child(self, layer_parent.get_child_count() - 1)


# 计算完整幕布揭开的总时长。
func _transition_duration() -> float:
	return _reveal_start_time() + reveal_seconds


# 计算标题停留结束、撕幕开始的时刻。
func _reveal_start_time() -> float:
	return silence_seconds + slash_seconds + title_pop_seconds + title_hold_seconds


# 用立方缓出让斜切和揭幕逐渐减速。
func _ease_out(value: float) -> float:
	return 1.0 - pow(1.0 - clampf(value, 0.0, 1.0), 3.0)


# 生成标题短促越位后回弹的缓动曲线。
func _ease_out_back(value: float) -> float:
	const C1: float = 1.70158
	const C3: float = C1 + 1.0
	var progress: float = clampf(value, 0.0, 1.0)
	return 1.0 + C3 * pow(progress - 1.0, 3.0) + C1 * pow(progress - 1.0, 2.0)
