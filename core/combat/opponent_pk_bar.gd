class_name OpponentPKBar
extends Node

var _hit_resolution: HitResolution
var _pullback_speed: float = 0.0
var _is_pullback_active: bool = false


func _ready() -> void:
	# 全局暂停时由 SceneTree 停止此节点处理，避免回拉继续推进。
	process_mode = Node.PROCESS_MODE_PAUSABLE


func start_pullback(hit_resolution: HitResolution, speed: float) -> void:
	# 普通战斗开始时绑定唯一 PK 所有者和当前回拉速度，不复制玩家 PK。
	_hit_resolution = hit_resolution
	_pullback_speed = speed
	_is_pullback_active = true


func stop_pullback() -> void:
	# 普通战斗结束或切入其他阶段时停止回拉。
	_is_pullback_active = false


func resume_pullback() -> void:
	# 恢复普通战斗时沿用当前速度和唯一 PK 所有者继续回拉。
	if _hit_resolution != null:
		_is_pullback_active = true


func _process(delta: float) -> void:
	# 仅在显式启动后逐帧计算回拉量，并把负增量交给 HitResolution。
	if not _is_pullback_active or _hit_resolution == null:
		return

	var pullback_amount: float = calculate_pullback_amount(_pullback_speed, delta)
	if pullback_amount > 0.0:
		_hit_resolution.apply_player_pk_delta(-pullback_amount)


func calculate_pullback_amount(speed: float, elapsed_seconds: float) -> float:
	# 回拉量为每秒扣减值乘经过的游戏秒数；非正输入不会增加玩家 PK。
	if speed <= 0.0 or elapsed_seconds <= 0.0:
		return 0.0
	return speed * elapsed_seconds
