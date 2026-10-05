class_name HitResolution
extends RefCounted

const _NORMAL_WORD_REWARDS_BY_STRENGTH: Dictionary = {
	1: {"pk_delta": 0.0012, "tendency_delta": 1},
	2: {"pk_delta": 0.002, "tendency_delta": 5},
	3: {"pk_delta": 0.005, "tendency_delta": 10},
}

var _player_pk: float = 0.0
var _minimum_player_pk: float = 0.0
var _maximum_player_pk: float = 1.0


func _init(initial_pk: float, minimum_pk: float, maximum_pk: float) -> void:
	# 创建本场唯一 PK 状态，并将配置初始值限制在配置范围内。
	initialize_player_pk(initial_pk, minimum_pk, maximum_pk)


func initialize_player_pk(initial_pk: float, minimum_pk: float, maximum_pk: float) -> void:
	# 开始或重开时替换范围与初始值，玩家 PK 始终由本对象持有。
	_minimum_player_pk = minimum_pk
	_maximum_player_pk = maximum_pk
	_player_pk = _clamp_player_pk(initial_pk)


func apply_player_pk_delta(delta: float) -> float:
	# 命中、惩罚或回拉都通过这里修改唯一 PK，并立即限制到合法范围。
	_player_pk = _clamp_player_pk(_player_pk + delta)
	return _player_pk


func get_player_pk() -> float:
	# 只读提供玩家 PK；对手显示值由读取方按需从总量中计算。
	return _player_pk


func calculate_normal_word_reward(strength: int) -> Dictionary:
	# 固定收益只由话语强度决定；Tier 不参与计算，本方法也不直接更新 PK 或倾向。
	if not _NORMAL_WORD_REWARDS_BY_STRENGTH.has(strength):
		push_error("Normal word strength must be 1, 2, or 3; received %d." % strength)
		return {}
	return _NORMAL_WORD_REWARDS_BY_STRENGTH[strength].duplicate()


func calculate_repeat_hit_result() -> Dictionary:
	# 复读是有效命中，但不产生 PK 或倾向收益，避免被整发结算误判为落空。
	return {"is_valid_hit": true, "pk_delta": 0.0, "tendency_delta": 0}


func resolve_shot_results(target_results: Array[Dictionary]) -> Dictionary:
	# 保留逐目标结算数据，只把 PK 增量求和后统一更新一次并应用范围限制。
	var total_pk_delta: float = 0.0
	for target_result: Dictionary in target_results:
		total_pk_delta += float(target_result.get("pk_delta", 0.0))

	var final_player_pk: float = apply_player_pk_delta(total_pk_delta)
	return {
		"total_pk_delta": total_pk_delta,
		"final_player_pk": final_player_pk,
		"target_results": target_results.duplicate(true),
	}


func _clamp_player_pk(value: float) -> float:
	return clampf(value, _minimum_player_pk, _maximum_player_pk)
