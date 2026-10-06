class_name AttackChargeInput
extends Node

signal shot_snapshot_created(snapshot: AttackTargetSnapshot)
signal shot_arrival_resolved(snapshot: AttackTargetSnapshot, target_results: Array[Dictionary])

enum AttackPhase { READY, PROJECTILE_FLIGHT, RECOVERY }

var _charge_progress: AttackChargeProgress
var _was_attack_held: bool = false
var _aim_reticle: AimReticle
var _barrage_area: BarrageArea
var _attack_timing: AttackTimingConfig
var _attack_phase: AttackPhase = AttackPhase.READY
var _phase_timer: Timer
var _active_snapshot: AttackTargetSnapshot
var _attack_held: bool = false


# 每帧读取全局按住状态并累计蓄力；松开瞬间由 _input 处理目标快照。
func _process(delta: float) -> void:
	if _charge_progress == null or get_tree().paused:
		return
	if _attack_phase != AttackPhase.READY:
		# 飞行和硬直期间不推进蓄力。
		return
	if _attack_held:
		_charge_progress.advance(delta, true)


func _ready() -> void:
	# 暂停期间仍接收鼠标抬起以清理按住状态，蓄力本身由下方显式跳过。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_phase_timer = Timer.new()
	# 计时器沿用 Godot 的暂停处理，在暂停中保留剩余时间。
	_phase_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_phase_timer.one_shot = true
	_phase_timer.timeout.connect(_on_attack_phase_timer_timeout)
	add_child(_phase_timer)


# 注入本场读取到的数值配置；正式运行时由共享数值表提供，测试可注入 fixture。
func configure_attack_timing(timing_config: AttackTimingConfig) -> bool:
	if timing_config == null or timing_config.charge_time_s <= 0.0:
		return false
	if timing_config.projectile_flight_s < 0.0 or timing_config.recovery_time_s < 0.0:
		return false
	if _attack_phase != AttackPhase.READY:
		return false

	_attack_timing = timing_config
	_charge_progress = AttackChargeProgress.new(timing_config.charge_time_s)
	return true


# 由 Sandbox 注入已存在的准心和弹幕区域，避免依赖场景内部 NodePath。
func configure_target_query(aim_reticle: AimReticle, barrage_area: BarrageArea) -> void:
	_aim_reticle = aim_reticle
	_barrage_area = barrage_area


# 在鼠标松开输入事件上冻结当前候选，之后进入准心的弹幕不加入本发。
func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		if not get_tree().paused and can_start_charging():
			_attack_held = true
		return

	var was_attack_held: bool = _attack_held
	_attack_held = false
	if was_attack_held and not get_tree().paused:
		_handle_attack_release()


# 未满蓄释放只取消；满蓄释放发送快照事实，不在攻击系统改动 PK。
func _handle_attack_release() -> void:
	if _charge_progress == null or _attack_phase != AttackPhase.READY:
		return
	if not _charge_progress.is_fully_charged():
		_charge_progress.cancel_if_undercharged()
		return

	var snapshot: AttackTargetSnapshot = _capture_target_snapshot()
	if _charge_progress.consume_fully_charged():
		_active_snapshot = snapshot
		_attack_phase = AttackPhase.PROJECTILE_FLIGHT
		_phase_timer.start(_attack_timing.projectile_flight_s)
		shot_snapshot_created.emit(snapshot)


# 飞行计时结束时复核快照目标并提交到达事实，随后开始硬直计时。
func _on_attack_phase_timer_timeout() -> void:
	if _attack_phase == AttackPhase.PROJECTILE_FLIGHT:
		var valid_targets: Array[Node] = _active_snapshot.resolve_present_targets(_barrage_area)
		var target_results: Array[Dictionary] = _build_target_trait_results(valid_targets)
		_attack_phase = AttackPhase.RECOVERY
		shot_arrival_resolved.emit(_active_snapshot, target_results)
		_phase_timer.start(_attack_timing.recovery_time_s)
		return

	if _attack_phase == AttackPhase.RECOVERY:
		_active_snapshot = null
		_attack_phase = AttackPhase.READY


# 将真实有效目标的最终特性结果随目标一起交给后续结算，不复制 4 系统规则。
func _build_target_trait_results(valid_targets: Array[Node]) -> Array[Dictionary]:
	var target_results: Array[Dictionary] = []
	for target_node in valid_targets:
		if not target_node is BarrageView:
			continue
		var barrage_view := target_node as BarrageView
		if barrage_view.runtime_record == null or barrage_view.runtime_record.trait_set == null:
			continue

		var trait_result: BarrageTraitResult = barrage_view.runtime_record.trait_set.get_hit_result()
		target_results.append(
			{
				"target_instance_id": barrage_view.get_instance_id(),
				"target": barrage_view,
				"trait_result": trait_result,
			}
		)
	return target_results


# 只从 BarrageArea 当前真实视图中筛选有效、可选、在区域内且与准心相交的弹幕。
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
		if barrage_view.runtime_record == null or barrage_view.runtime_record.trait_set == null:
			continue
		if not barrage_view.runtime_record.trait_set.is_selectable():
			continue
		if current_time_msec >= barrage_view.runtime_record.expires_at_msec:
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


# 供 UI 和后续攻击流程读取当前阶段，不复制组件内部计时状态。
func get_attack_phase() -> AttackPhase:
	return _attack_phase


# 蓄力配置有效且未处于飞行或硬直时才能开始下一发。
func can_start_charging() -> bool:
	return _charge_progress != null and _attack_phase == AttackPhase.READY and not get_tree().paused
