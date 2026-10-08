extends SceneTree

const CANDIDATE_FILTER = preload("res://core/divine_descent/divine_descent_candidate_filter.gd")


# 只执行 DD-06 指定的两个权重规则用例。
func _init() -> void:
	var addition_passed: bool = _test_normal_addition()
	var minimum_passed: bool = _test_minimum_one()
	quit(0 if addition_passed and minimum_passed else 1)


# 使用 DD-02 的分离历史来源，验证命中数与实际普通复读数相加。
func _test_normal_addition() -> bool:
	var committed_hit_history: Array[Dictionary] = [{
		"original_sentence_id": "line-a",
		"tendency": "orthodox",
		"hit_count": 3,
		"first_committed_hit_order": 1,
	}]
	var candidates: Array[Dictionary] = CANDIDATE_FILTER.new().build_history_candidates(
		committed_hit_history, {"line-a": 5}
	)
	var weighted_candidates: Array[Dictionary] = CANDIDATE_FILTER.calculate_base_weights(candidates)
	if int(weighted_candidates[0]["base_weight"]) != 8:
		push_error("DD-06 normal addition failed: expected 3 + 5 = 8")
		return false
	print("PASS DD-06 normal addition: 3 + 5 = 8")
	return true


# 候选两项统计均为零时，基础权重仍取 1。
func _test_minimum_one() -> bool:
	var candidates: Array[Dictionary] = [{"hit_count": 0, "normal_repeat_count": 0}]
	var weighted_candidates: Array[Dictionary] = CANDIDATE_FILTER.calculate_base_weights(candidates)
	if int(weighted_candidates[0]["base_weight"]) != 1:
		push_error("DD-06 minimum weight failed: expected 1")
		return false
	print("PASS DD-06 minimum weight: 0 + 0 -> 1")
	return true
