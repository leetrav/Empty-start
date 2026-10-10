class_name OpponentTierFx
extends Control

@export var sweat_anchor: Vector2 = Vector2(0.72, 0.22)
@export var sweat_size: float = 26.0
@export var sweat_period: float = 1.75
@export var impact_strength: float = 1.0

var sweat_alpha: float = 0.0:
	set(value):
		sweat_alpha = clampf(value, 0.0, 1.0)
		queue_redraw()

var _time: float = 0.0
var _impact_left: float = 0.0
var _sweat_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


# T2 时淡入两滴循环滑落的程序水滴，离开 T2 时淡出。
func set_sweat(enabled: bool) -> void:
	if _sweat_tween != null:
		_sweat_tween.kill()
	set_process(enabled or sweat_alpha > 0.0 or _impact_left > 0.0)
	_sweat_tween = create_tween()
	_sweat_tween.tween_property(self, "sweat_alpha", 1.0 if enabled else 0.0, 0.16 if enabled else 0.12)
	if not enabled:
		_sweat_tween.tween_callback(_stop_if_idle)


# 换图瞬间的漫画冲击只属于立绘局部，不改变战斗受击判定。
func play_impact() -> void:
	_impact_left = 0.23
	set_process(true)
	queue_redraw()


func reset_fx() -> void:
	if _sweat_tween != null:
		_sweat_tween.kill()
	sweat_alpha = 0.0
	_impact_left = 0.0
	_time = 0.0
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	_impact_left = maxf(0.0, _impact_left - delta)
	queue_redraw()
	_stop_if_idle()


func _stop_if_idle() -> void:
	if sweat_alpha <= 0.0 and _impact_left <= 0.0:
		set_process(false)


func _draw() -> void:
	if sweat_alpha > 0.0:
		var unit: float = minf(size.x / 448.0, size.y / 432.0)
		for index: int in 2:
			var phase: float = fposmod(_time / maxf(sweat_period, 0.1) + float(index) * 0.52, 1.0)
			var life: float = sin(phase * PI) * sweat_alpha
			var center: Vector2 = size * sweat_anchor + Vector2(float(index) * 30.0 - 12.0, phase * 24.0) * unit
			_draw_drop(center, sweat_size * unit * (1.0 - phase * 0.12), life)
	if _impact_left > 0.0:
		var fade: float = _impact_left / 0.23 * impact_strength
		var center: Vector2 = size * Vector2(0.52, 0.45)
		var radius: float = minf(size.x, size.y) * 0.31
		for index: int in 8:
			var angle: float = TAU * float(index) / 8.0 + 0.18
			var direction := Vector2.RIGHT.rotated(angle)
			var side := direction.orthogonal()
			var origin: Vector2 = center + direction * radius
			var tip: Vector2 = center + direction * radius * 1.55
			draw_colored_polygon(PackedVector2Array([origin - side * 4.0, tip, origin + side * 4.0]), Color(1.0, 0.87, 0.28, fade))
			draw_line(origin, tip, Color(0.18, 0.12, 0.22, fade), 2.0)


func _draw_drop(center: Vector2, radius: float, alpha: float) -> void:
	var outline := PackedVector2Array([
		center + Vector2(0.0, -radius * 1.45),
		center + Vector2(radius * 0.72, -radius * 0.15),
		center + Vector2(radius * 0.78, radius * 0.48),
		center + Vector2(0.0, radius),
		center + Vector2(-radius * 0.78, radius * 0.48),
		center + Vector2(-radius * 0.72, -radius * 0.15)
	])
	draw_colored_polygon(outline, Color(0.12, 0.18, 0.29, alpha))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -radius * 1.15),
		center + Vector2(radius * 0.52, -radius * 0.07),
		center + Vector2(radius * 0.55, radius * 0.43),
		center + Vector2(0.0, radius * 0.72),
		center + Vector2(-radius * 0.55, radius * 0.43),
		center + Vector2(-radius * 0.52, -radius * 0.07)
	]), Color(0.36, 0.86, 1.0, alpha))
	draw_line(center + Vector2(-radius * 0.26, -radius * 0.20), center + Vector2(-radius * 0.10, -radius * 0.55), Color(1.0, 1.0, 1.0, alpha), maxf(2.0, radius * 0.12))
