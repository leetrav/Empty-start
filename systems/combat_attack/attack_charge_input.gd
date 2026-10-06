class_name AttackChargeInput
extends Node

signal shot_snapshot_created(snapshot: AttackTargetSnapshot)

@export var charge_duration_seconds: float = 0.8

var _charge_progress: AttackChargeProgress
var _was_attack_held: bool = false
var _aim_reticle: AimReticle
var _barrage_area: BarrageArea


# 每帧读取全局按住状态并累计蓄力；松开瞬间由 _input 处理目标快照。
func _process(delta: float) -> void:
	if _charge_progress == null:
		return

	var is_attack_held: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if is_attack_held:
		_charge_progress.advance(delta, true)
	elif _was_attack_held:
		# 窗口失焦等情况下若收不到释放事件，按全局输入状态兜底处理。
		_handle_attack_release()
	_was_attack_held = is_attack_held


func _ready() -> void:
	_charge_progress = AttackChargeProgress.new(charge_duration_seconds)


# 由 Sandbox 注入已存在的准心和弹幕区域，避免依赖场景内部 NodePath。
func configure_target_query(aim_reticle: AimReticle, barrage_area: BarrageArea) -> void:
	_aim_reticle = aim_reticle
	_barrage_area = barrage_area


# 在鼠标松开输入事件上冻结当前候选，之后进入准心的弹幕不加入本发。
func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or mouse_event.pressed:
		return
	_handle_attack_release()
	_was_attack_held = false


# 未满蓄释放只取消；满蓄释放发送快照事实，不在攻击系统改动 PK。
func _handle_attack_release() -> void:
	if _charge_progress == null:
		return
	if not _charge_progress.is_fully_charged():
		_charge_progress.cancel_if_undercharged()
		return

	var snapshot: AttackTargetSnapshot = _capture_target_snapshot()
	if _charge_progress.consume_fully_charged():
		shot_snapshot_created.emit(snapshot)


# 只从 BarrageArea 当前真实视图中筛选有效、在区域内且与准心相交的弹幕。
func _capture_target_snapshot() -> AttackTargetSnapshot:
	var candidates: Array[Node] = []
	if _aim_reticle == null or _barrage_area == null:
		return AttackTargetSnapshot.capture_at_release(candidates)

	var current_time_msec: int = Time.get_ticks_msec()
	var area_rect: Rect2 = _barrage_area.get_global_rect()
	for child in _barrage_area.get_children():
		if not child is BarrageView:
			continue
		var barrage_view := child as BarrageView
		if not barrage_view.is_inside_tree() or barrage_view.is_queued_for_deletion():
			continue
		if barrage_view.runtime_record == null or current_time_msec >= barrage_view.runtime_record.expires_at_msec:
			continue

		var target_rect: Rect2 = barrage_view.get_global_rect()
		var visible_target_rect: Rect2 = area_rect.intersection(target_rect)
		if visible_target_rect.size.x <= 0.0 or visible_target_rect.size.y <= 0.0:
			continue
		if _aim_reticle.intersects_target_area(visible_target_rect):
			candidates.append(barrage_view)

	return AttackTargetSnapshot.capture_at_release(candidates)


# 提供给后续攻击反馈和释放流程读取当前蓄力比例。
func get_charge_progress() -> float:
	return _charge_progress.get_progress() if _charge_progress != null else 0.0


# 提供给后续释放流程判断是否已经蓄满。
func is_fully_charged() -> bool:
	return _charge_progress != null and _charge_progress.is_fully_charged()
