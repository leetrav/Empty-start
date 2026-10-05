class_name OpponentPKBar
extends RefCounted


func calculate_pullback_amount(speed: float, elapsed_seconds: float) -> float:
	# 回拉量为每秒扣减值乘经过的游戏秒数；非正输入不会增加玩家 PK。
	if speed <= 0.0 or elapsed_seconds <= 0.0:
		return 0.0
	return speed * elapsed_seconds
