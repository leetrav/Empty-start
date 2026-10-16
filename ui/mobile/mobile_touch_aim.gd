class_name MobileTouchAim
extends Control

signal aim_changed(aim_viewport_position: Vector2)
signal gesture_cancelled(reason: StringName)
signal safe_area_changed(safe_viewport_rect: Rect2)

## 本组件只适配指针和反馈，蓄力、命中、飞行仍调用 C 的公开入口。
@export var layout: MobileTouchLayout
var _attack: Node
var _enabled: bool = false
var _finger: int = -1
var _finger_position: Vector2
var _aim_position: Vector2
var _aim_bounds: Rect2
var _touch_bounds: Rect2
var _preview_dpi: float = 0.0
var _preview_safe_rect: Rect2
var _last_safe_rect: Rect2
var _cue_remaining: float = 0.0

@onready var _feedback: PanelContainer = %Feedback
@onready var _status: Label = %Status
@onready var _progress: ProgressBar = %Progress


## 默认关闭；A 在正确战斗阶段显式启用，避免自动抢走菜单/休息输入。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_on_viewport_changed)
	_feedback.visible = _enabled
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 仅绑定已交付的公开方法；旧 C 代码缺接口时明确返回失败。
func bind_attack_input(attack: Node) -> bool:
	for method: String in ["begin_pointer_attack", "move_pointer_aim", "end_pointer_attack", "cancel_pointer_attack", "set_native_touch_input_enabled", "get_charge_progress", "is_charge_held", "is_fully_charged", "get_attack_phase"]:
		if attack == null or not attack.has_method(method):
			return false
	if is_instance_valid(_attack):
		cancel_gesture(&"rebind")
		_attack.call("set_native_touch_input_enabled", true)
	_attack = attack
	_attack.call("set_native_touch_input_enabled", not _enabled)
	return true


## 区域使用InputEvent.position同一Viewport坐标；空触摸区沿用瞄准区。
func configure_regions(aim_viewport_rect: Rect2, touch_viewport_rect: Rect2 = Rect2()) -> void:
	cancel_gesture(&"region_changed")
	_aim_bounds = aim_viewport_rect
	_touch_bounds = touch_viewport_rect if touch_viewport_rect.has_area() else aim_viewport_rect


## 用显式布局开启适配；与 C 原生触摸通道互斥，鼠标通道保持原业务。
func set_enabled(active: bool) -> bool:
	if active and (layout == null or layout.aim_offset_mm.is_zero_approx() or not is_instance_valid(_attack)):
		return false
	if not active:
		cancel_gesture(&"disabled")
	_enabled = active
	if is_instance_valid(_attack):
		_attack.call("set_native_touch_input_enabled", not active)
	if is_node_ready():
		_feedback.visible = active
		_layout_feedback()
	return true


## 虚拟设备按1Viewport像素=1屏幕像素注入密度/刘海；真机直接读DisplayServer。
func set_preview_metrics(dpi: float, safe_viewport_rect: Rect2) -> void:
	cancel_gesture(&"display_changed")
	_preview_dpi = dpi
	_preview_safe_rect = safe_viewport_rect
	if is_node_ready():
		_layout_feedback()


## Android安全区是屏幕像素，先逆变换到Viewport再交给 A/D 排版。
func get_safe_viewport_rect() -> Rect2:
	var visible_rect: Rect2 = get_viewport().get_visible_rect()
	if _preview_safe_rect.has_area():
		return visible_rect.intersection(_preview_safe_rect)
	if not OS.has_feature("mobile"):
		return visible_rect
	var screen_rect := Rect2(DisplayServer.get_display_safe_area())
	if not screen_rect.has_area():
		return visible_rect
	return visible_rect.intersection(get_viewport().get_screen_transform().affine_inverse() * screen_rect)


## 供手动预览和宿主读取同一偏置结果，命中仍由AttackChargeInput决定。
func get_aim_viewport_position() -> Vector2:
	return _aim_position


## 所有取消入口共用真实攻击取消，满蓄也不会在返回前台后误发。
func cancel_gesture(reason: StringName = &"cancelled") -> void:
	if _finger < 0:
		return
	_finger = -1
	if is_instance_valid(_attack):
		_attack.call("cancel_pointer_attack")
	_cue_remaining = 0.0
	gesture_cancelled.emit(reason)
	queue_redraw()


## 已捕获手指在UI上抬起也要释放；其他手指保留给UI，不能替换主手指。
func _input(event: InputEvent) -> void:
	if not _enabled or _finger < 0:
		return
	if not is_instance_valid(_attack):
		cancel_gesture(&"source_removed")
		return
	if event is InputEventScreenDrag and event.index == _finger:
		if not get_tree().paused:
			_move_aim(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.index == _finger and (not event.pressed or event.canceled):
		if event.canceled or get_tree().paused:
			cancel_gesture(&"system_cancel")
		else:
			_move_aim(event.position)
			_finger = -1
			_attack.call("end_pointer_attack", _aim_position, true)
			_cue_remaining = 0.3
		get_viewport().set_input_as_handled()


## 只从未被按钮消费的安全触摸区域开始；拒绝重复按下和额外手指。
func _unhandled_input(event: InputEvent) -> void:
	if not _enabled or _finger >= 0 or get_tree().paused or not is_instance_valid(_attack):
		return
	if not event is InputEventScreenTouch or not event.pressed or event.canceled:
		return
	var region: Rect2 = _touch_bounds if _touch_bounds.has_area() else get_safe_viewport_rect()
	if not region.intersection(get_safe_viewport_rect()).has_point(event.position):
		return
	if _aim_bounds.has_area() and not _aim_bounds.intersection(get_safe_viewport_rect()).has_area():
		return
	_move_aim(event.position)
	if not bool(_attack.call("begin_pointer_attack", _aim_position, true)):
		return
	_finger = event.index
	_cue_remaining = 0.0
	get_viewport().set_input_as_handled()


## 触点偏置按设备密度换算，超边界时选更远的可见方向，避免又落回指肚下。
func _move_aim(position_in_viewport: Vector2) -> void:
	_finger_position = position_in_viewport
	var scale_to_viewport: Transform2D = _screen_to_viewport()
	var offset: Vector2 = scale_to_viewport.basis_xform(layout.aim_offset_mm * _dpi() / 25.4)
	var bounds: Rect2 = get_safe_viewport_rect()
	if _aim_bounds.has_area():
		bounds = bounds.intersection(_aim_bounds)
	var margin: float = scale_to_viewport.basis_xform(Vector2(layout.edge_margin_mm * _dpi() / 25.4, 0)).length()
	if bounds.size.x > margin * 2.0 and bounds.size.y > margin * 2.0:
		bounds = bounds.grow(-margin)
	var best: Vector2 = (position_in_viewport + offset).clamp(bounds.position, bounds.end)
	if best.distance_to(position_in_viewport) < offset.length() * 0.7:
		for candidate_offset: Vector2 in [offset.rotated(PI * 0.5), offset.rotated(-PI * 0.5), -offset]:
			var candidate: Vector2 = (position_in_viewport + candidate_offset).clamp(bounds.position, bounds.end)
			if candidate.distance_to(position_in_viewport) > best.distance_to(position_in_viewport):
				best = candidate
	_aim_position = best
	_attack.call("move_pointer_aim", best, true)
	aim_changed.emit(best)
	queue_redraw()


## 反馈只读取真实进度，不生成第二套蓄力计时。
func _process(delta: float) -> void:
	if not _enabled or not is_instance_valid(_attack):
		return
	if get_tree().paused:
		cancel_gesture(&"paused")
	var safe_rect: Rect2 = get_safe_viewport_rect()
	if safe_rect != _last_safe_rect:
		cancel_gesture(&"safe_area_changed")
		_layout_feedback()
	var progress: float = float(_attack.call("get_charge_progress"))
	var held: bool = bool(_attack.call("is_charge_held"))
	_progress.value = progress * 100.0
	_status.text = "松开发射" if bool(_attack.call("is_fully_charged")) else ("长按蓄力 %d%%" % roundi(progress * 100.0) if held else "长按并拖动瞄准")
	var phase: int = int(_attack.call("get_attack_phase"))
	if phase == AttackChargeInput.AttackPhase.PROJECTILE_FLIGHT:
		_status.text = "言弹飞行中"
	elif phase == AttackChargeInput.AttackPhase.RECOVERY:
		_status.text = "已预按 · 恢复后继续蓄力" if held else "恢复中 · 可预先按住"
	if get_tree().paused:
		_status.text = "已暂停 · 恢复后重新按住"
	_cue_remaining = maxf(0.0, _cue_remaining - delta)
	queue_redraw()


## 状态条放进安全区，物理密度与画布缩放分别换算。
func _layout_feedback() -> void:
	if not is_node_ready() or layout == null:
		return
	var safe_rect: Rect2 = get_safe_viewport_rect()
	_last_safe_rect = safe_rect
	var inverse: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var local_safe: Rect2 = inverse * safe_rect
	var units_per_mm: float = inverse.basis_xform(_screen_to_viewport().basis_xform(Vector2(_dpi() / 25.4, 0))).length()
	_status.add_theme_font_size_override("font_size", maxi(18, roundi(layout.feedback_font_mm * units_per_mm)))
	_feedback.size = Vector2(minf(layout.feedback_width_mm * units_per_mm, local_safe.size.x * 0.8), maxf(64.0, 8.0 * units_per_mm))
	_feedback.position = (local_safe.position + local_safe.size * layout.feedback_anchor - _feedback.size * 0.5).clamp(local_safe.position, local_safe.end - _feedback.size)
	safe_area_changed.emit(safe_rect)


## 旋转/窗口变化取消当前手势，让下一次按下采用新坐标系。
func _on_viewport_changed() -> void:
	cancel_gesture(&"viewport_changed")
	_layout_feedback()


## Android DPI为密度分组估计；没有可靠设备值时使用系统mdpi基准。
func _dpi() -> float:
	var actual_dpi: float = float(DisplayServer.screen_get_dpi())
	return _preview_dpi if _preview_dpi > 0.0 else (actual_dpi if actual_dpi > 0.0 else 160.0)


## 独立纹理预览没有系统窗口坐标；真机路径始终使用真实屏幕逆变换。
func _screen_to_viewport() -> Transform2D:
	return Transform2D.IDENTITY if _preview_dpi > 0.0 else get_viewport().get_screen_transform().affine_inverse()


## 细线只解释手指与真实瞄准中心的关系，准心仍由现有AimReticle绘制。
func _draw() -> void:
	if not _enabled or (_finger < 0 and _cue_remaining <= 0.0):
		return
	var inverse: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var finger: Vector2 = inverse * _finger_position
	var aim: Vector2 = inverse * _aim_position
	draw_line(finger, aim, Color(0.05, 0.08, 0.11, 0.9), 7.0, true)
	draw_line(finger, aim, Color(0.4, 1.0, 0.85, 0.9), 2.5, true)
	draw_arc(finger, 12.0, 0.0, TAU, 32, Color(0.8, 0.9, 1.0, 0.8), 2.0, true)


## 切后台或离树取消输入；解绑时恢复 C 的原生通道。
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		cancel_gesture(&"focus_lost")


## 只恢复自己接管过的输入源，组件可独立挂载和移除。
func _exit_tree() -> void:
	cancel_gesture(&"removed")
	if is_instance_valid(_attack):
		_attack.call("set_native_touch_input_enabled", true)
