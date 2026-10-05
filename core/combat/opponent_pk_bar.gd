class_name OpponentPKBar
extends Node

var _hit_resolution: HitResolution
var _pullback_speed: float = 0.0
var _is_pullback_active: bool = false


func start_pullback(hit_resolution: HitResolution, speed: float) -> void:
	# 普通战斗开始时绑定唯一 PK 所有者和当前回拉速度，不复制玩家 PK。
	_hit_resolution = hit_resolution
	_pullback_speed = speed
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
