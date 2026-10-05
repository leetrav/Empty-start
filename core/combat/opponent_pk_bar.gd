class_name OpponentPKBar
extends Node

signal attempt_failed

var _hit_resolution: HitResolution
var _base_pullback_speed: float = 0.0
var _pullback_multiplier: float = 1.0
var _is_pullback_active: bool = false
var _attempt_failed: bool = false
var _loss_streak_count: int = 0


func _ready() -> void:
	# 全局暂停时由 SceneTree 停止此节点处理，避免回拉继续推进。
	process_mode = Node.PROCESS_MODE_PAUSABLE


func start_pullback(hit_resolution: HitResolution, base_speed: float) -> void:
	# 普通战斗开始时绑定唯一 PK 所有者和当前回拉速度，不复制玩家 PK。
	if _attempt_failed:
		return
	_hit_resolution = hit_resolution
	_base_pullback_speed = base_speed
	_is_pullback_active = true


func update_pullback_multiplier(multiplier: float) -> void:
	# Tier 变化只影响后续帧的回拉速度，已经结算的时间不会重新计算。
	_pullback_multiplier = maxf(multiplier, 0.0)


func stop_pullback() -> void:
	# 普通战斗结束或切入其他阶段时停止回拉。
	_is_pullback_active = false


func resume_pullback() -> void:
	# 恢复普通战斗时沿用当前速度和唯一 PK 所有者继续回拉。
	if _hit_resolution != null and not _attempt_failed:
		_is_pullback_active = true


func has_attempt_failed() -> bool:
	return _attempt_failed


func record_current_level_failure() -> int:
	# 每次当前关失败只由失败流程调用一次，并递增本关连败数。
	_loss_streak_count += 1
	return _loss_streak_count


func complete_current_level() -> void:
	# 完成本关后清零，下一关从零开始计算连败。
	_loss_streak_count = 0


func start_new_run() -> void:
	# 新周目与当前关进度无关，连败记录重新开始。
	_loss_streak_count = 0


func get_loss_streak_count() -> int:
	return _loss_streak_count


func _process(delta: float) -> void:
	# 仅在显式启动后逐帧计算回拉量，并把负增量交给 HitResolution。
	if not _is_pullback_active or _hit_resolution == null or _attempt_failed:
		return
	if _hit_resolution.get_player_pk() <= 0.0:
		_mark_attempt_failed()
		return

	var current_speed: float = _base_pullback_speed * _pullback_multiplier
	var pullback_amount: float = calculate_pullback_amount(current_speed, delta)
	if pullback_amount > 0.0:
		_hit_resolution.apply_player_pk_delta(-pullback_amount)
		if _hit_resolution.get_player_pk() <= 0.0:
			_mark_attempt_failed()


func _mark_attempt_failed() -> void:
	# 本场失败只通知一次；监听方负责关闭攻击入口并显示失败流程。
	if _attempt_failed:
		return
	_attempt_failed = true
	_is_pullback_active = false
	attempt_failed.emit()


func calculate_pullback_amount(speed: float, elapsed_seconds: float) -> float:
	# 回拉量为每秒扣减值乘经过的游戏秒数；非正输入不会增加玩家 PK。
	if speed <= 0.0 or elapsed_seconds <= 0.0:
		return 0.0
	return speed * elapsed_seconds
