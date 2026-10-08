extends SceneTree

const CANDIDATE_FILTER = preload("res://core/divine_descent/divine_descent_candidate_filter.gd")


# 只运行 DD-09 指定的一项关键单测：最高当前动态权重胜出。
func _init() -> void:
	call_deferred("_test_highest_weight_wins")


# 故意让基础权重与当前权重排名不同，确认锁句读取扩散后的 weight。
func _test_highest_weight_wins() -> void:
	var candidates: Array[Dictionary] = [
		{"original_sentence_id": "line-a", "base_weight": 5, "weight": 6},
		{"original_sentence_id": "line-b", "base_weight": 1, "weight": 13},
		{"original_sentence_id": "line-c", "base_weight": 9, "weight": 10},
	]
	var selected: Dictionary = CANDIDATE_FILTER.select_highest_weight_candidate(candidates)
	var passed: bool = selected.get("original_sentence_id") == "line-b" and selected.get("weight") == 13
	selected["weight"] = 999
	passed = passed and candidates[1]["weight"] == 13
	if not passed:
		push_error("DD-09 highest current weight selection failed")
		quit(1)
		return
	print("PASS DD-09 highest weight wins: current weights 6/13/10 select line-b")
	quit(0)
