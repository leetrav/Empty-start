extends SceneTree

const CANDIDATE_FILTER = preload("res://core/divine_descent/divine_descent_candidate_filter.gd")


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var filter = CANDIDATE_FILTER.new()
	var committed_history: Array[Dictionary] = [
		{
			"original_sentence_id": "line-a",
			"original_sentence_text": "第一句",
			"tendency": "orthodox",
			"hit_count": 2,
			"normal_repeat_count": 3,
			"first_committed_hit_order": 2,
		},
		{
			"original_sentence_id": "line-a",
			"original_sentence_text": "第一句",
			"tendency": "orthodox",
			"hit_count": 1,
			"normal_repeat_count": 2,
			"first_committed_hit_order": 5,
		},
		{
			"original_sentence_id": "neutral-line",
			"original_sentence_text": "中性句",
			"tendency": "neutral",
			"hit_count": 9,
			"normal_repeat_count": 8,
		},
		{
			"original_sentence_id": "line-b",
			"original_sentence_text": "第二句",
			"tendency": "absurd",
			"hit_count": 1,
			"repeat_count": 4,
			"first_committed_hit_order": 7,
		},
	]

	var candidates: Array[Dictionary] = filter.build_history_candidates(committed_history)
	var passed: bool = candidates.size() == 2
	passed = passed and str(candidates[0].get("original_sentence_id", "")) == "line-a"
	passed = passed and int(candidates[0].get("hit_count", 0)) == 3
	passed = passed and int(candidates[0].get("normal_repeat_count", 0)) == 5
	passed = passed and int(candidates[0].get("first_committed_hit_order", 0)) == 2
	passed = passed and str(candidates[1].get("original_sentence_id", "")) == "line-b"
	passed = passed and int(candidates[1].get("hit_count", 0)) == 1
	passed = passed and int(candidates[1].get("normal_repeat_count", 0)) == 4

	if passed:
		print("PASS DD-02 history candidates merge hit and normal repeat counts")
		quit(0)
	else:
		push_error("DD-02 history candidate merge failed")
		quit(1)
