class_name StageArrowFx
extends Control

signal animation_finished(direction: int)
signal fade_started(direction: int)

@export var arrow_color: Color = Color(1.0, 0.94, 0.76, 0.78)
@export var outline_color: Color = Color(0.09, 0.10, 0.17, 0.78)
@export_range(0.08, 0.55, 0.01) var arrow_size_ratio: float = 0.28
@export_range(0.002, 0.04, 0.001) var outline_ratio: float = 0.012
@export_range(0.01, 0.5, 0.01) var pop_seconds: float = 0.12
@export_range(0.01, 0.5, 0.01) var thrust_seconds: float = 0.08
@export_range(0.0, 0.15, 0.005) var thrust_ratio: float = 0.025
@export_range(0.0, 0.5, 0.01) var hold_seconds: float = 0.08
@export_range(0.01, 0.6, 0.01) var fade_seconds: float = 0.20
@export_range(0.0, 0.3, 0.01) var travel_ratio: float = 0.09

var _direction: int = 0
var _elapsed: float = 0.0
var _playing: bool = false
var _fade_reported: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


# 只消费已确定的升降方向（+1 为上，-1 为下）；新事件会从零播放。
func play(direction: int) -> void:
	if direction == 0:
		return
	_direction = -1 if direction < 0 else 1
	_elapsed = 0.0
	_playing = true
	_fade_reported = false
	visible = true
	set_process(true)
	queue_redraw()


func reset_effect() -> void:
	_playing = false
	_elapsed = 0.0
	_direction = 0
	visible = false
	set_process(false)
	queue_redraw()


func is_playing() -> bool:
	return _playing


func _process(delta: float) -> void:
	_elapsed += delta
	var thrust_duration: float = thrust_seconds if _direction > 0 else 0.0
	# 从显现/上冲/停留进入淡出的真实帧通知音乐，禁止由外部猜延时。
	if not _fade_reported and _elapsed >= pop_seconds + thrust_duration + hold_seconds:
		_fade_reported = true
		fade_started.emit(_direction)
	if _elapsed >= pop_seconds + thrust_duration + hold_seconds + fade_seconds:
		var finished_direction: int = _direction
		reset_effect()
		animation_finished.emit(finished_direction)
		return
	queue_redraw()


func _draw() -> void:
	if not _playing or size.x <= 0.0 or size.y <= 0.0:
		return
	var alpha: float = 1.0
	var scale_factor: float = 1.0
	var travel: float = 0.0
	var thrust_duration: float = thrust_seconds if _direction > 0 else 0.0
	var thrust_end: float = pop_seconds + thrust_duration
	var thrust_distance: float = minf(size.x, size.y) * thrust_ratio if _direction > 0 else 0.0
	if _elapsed < pop_seconds:
		var t: float = _smooth(_elapsed / pop_seconds)
		alpha = t
		scale_factor = lerpf(0.66, 1.08, t)
	elif _elapsed < thrust_end:
		# 升档先上冲，再在上冲终点停留；降档沿用原短促节奏。
		var t: float = _smooth((_elapsed - pop_seconds) / maxf(thrust_duration, 0.001))
		scale_factor = lerpf(1.08, 1.0, t)
		travel = -thrust_distance * t
	elif _elapsed < thrust_end + hold_seconds:
		scale_factor = 1.0
		if _direction < 0:
			var t: float = _smooth((_elapsed - thrust_end) / maxf(hold_seconds, 0.001))
			scale_factor = lerpf(1.08, 1.0, t)
		travel = -thrust_distance
	else:
		var t: float = _smooth((_elapsed - thrust_end - hold_seconds) / fade_seconds)
		alpha = 1.0 - t
		scale_factor = lerpf(1.0, 0.91, t)
		travel = -thrust_distance - t * minf(size.x, size.y) * travel_ratio * float(_direction)
	var extent: float = minf(size.x, size.y) * arrow_size_ratio * scale_factor
	var center: Vector2 = size * 0.5 + Vector2(0.0, travel)
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(-0.52, 0.03), Vector2(0.0, -0.52), Vector2(0.52, 0.03),
		Vector2(0.23, 0.03), Vector2(0.23, 0.5), Vector2(-0.23, 0.5),
		Vector2(-0.23, 0.03),
	])
	var polygon: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		polygon.append(center + Vector2(point.x, point.y * float(_direction)) * extent)
	var fill: Color = arrow_color
	fill.a *= alpha
	var outline: Color = outline_color
	outline.a *= alpha
	draw_colored_polygon(polygon, fill)
	var closed: PackedVector2Array = polygon.duplicate()
	closed.append(polygon[0])
	draw_polyline(closed, outline, maxf(2.0, minf(size.x, size.y) * outline_ratio), true)


func _smooth(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
