extends SceneTree

const CANDIDATE_FILTER = preload("res://core/divine_descent/divine_descent_candidate_filter.gd")


# 只运行 DD-07 指定的正常加成与同句多章两项单测。
func _init() -> void:
	var normal_passed: bool = _test_normal_bonus()
	var once_passed: bool = _test_same_sentence_once()
	quit(0 if normal_passed and once_passed else 1)


# 使用真实 DD-06 输出验证统一最大基础加成，池外经文不会追加候选。
func _test_normal_bonus() -> bool:
	var candidates: Array[Dictionary] = [
		{"original_sentence_id": "line-a", "hit_count": 3, "normal_repeat_count": 5},
		{"original_sentence_id": "line-b", "hit_count": 1, "normal_repeat_count": 2},
		{"original_sentence_id": "line-c", "hit_count": 1, "normal_repeat_count": 0},
	]
	var base_candidates: Array[Dictionary] = CANDIDATE_FILTER.calculate_base_weights(candidates)
	var entries: Array[Dictionary] = [
		{"original_sentence_id": "line-a", "chapter_number": 1},
		{"original_sentence_id": "line-b", "chapter_number": 2},
		{"original_sentence_id": "outside-pool", "chapter_number": 3},
	]
	var result: Array[Dictionary] = CANDIDATE_FILTER.apply_scripture_bonus(base_candidates, entries)
	var passed: bool = result.size() == 3
	passed = passed and result[0]["weight"] == 16 and result[1]["weight"] == 11 and result[2]["weight"] == 1
	passed = passed and result[0]["base_weight"] == 8 and result[1]["base_weight"] == 3
	passed = passed and result[0]["original_sentence_id"] == "line-a" and result[1]["original_sentence_id"] == "line-b"
	result[0]["hit_count"] = 999
	passed = passed and base_candidates[0]["hit_count"] == 3 and not base_candidates[0].has("weight")
	passed = passed and entries.size() == 3 and entries[0]["original_sentence_id"] == "line-a"
	if not passed:
		push_error("DD-07 normal scripture bonus failed")
		return false
	print("PASS DD-07 normal bonus: max base 8 -> weights 16/11/1; pool unchanged")
	return true


# 同句跨多章和两种稳定 ID 字符串表示均只得到一次加成。
func _test_same_sentence_once() -> bool:
	var candidates: Array[Dictionary] = [
		{"original_sentence_id": "line-a", "hit_count": 3, "normal_repeat_count": 5},
		{"original_sentence_id": "line-b", "hit_count": 1, "normal_repeat_count": 2},
	]
	var base_candidates: Array[Dictionary] = CANDIDATE_FILTER.calculate_base_weights(candidates)
	var entries: Array[Dictionary] = [
		{"original_sentence_id": "line-b", "chapter_number": 1},
		{"original_sentence_id": &"line-b", "chapter_number": 4},
		{"original_sentence_id": "line-b", "chapter_number": 7},
	]
	var result: Array[Dictionary] = CANDIDATE_FILTER.apply_scripture_bonus(base_candidates, entries)
	var passed: bool = result.size() == 2 and result[0]["weight"] == 8 and result[1]["weight"] == 11
	passed = passed and result[1]["base_weight"] == 3 and entries.size() == 3
	if not passed:
		push_error("DD-07 repeated scripture sentence bonus failed")
		return false
	print("PASS DD-07 same sentence once: three chapters -> 3 + 8 = 11")
	return true
