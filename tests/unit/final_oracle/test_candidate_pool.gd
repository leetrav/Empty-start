extends SceneTree

const HIT_RESOLUTION = preload("res://core/combat/hit_resolution.gd")
const CANDIDATE_POOL = preload("res://core/final_oracle/final_oracle_candidate_pool.gd")
const REPEAT_PLAN = preload("res://core/repeat/repeat_plan.gd")
const REPEAT_STATS = preload("res://core/repeat/repeat_generation_stats.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	await process_frame
	if not _test_duplicate_history_rows_are_one_candidate():
		quit(1)
		return
	if not _test_only_normal_hit_history_enters_pool():
		quit(1)
		return
	if not _test_highest_normal_repeat_per_tendency():
		quit(1)
		return
	if not _test_latest_hit_breaks_repeat_tie():
		quit(1)
		return
	if not _test_stable_sentence_id_breaks_final_tie():
		quit(1)
		return
	print("通过：FO-02 候选池与 FO-03 / FO-04 候选排序")
	quit()


# 相同稳定原句 ID 只保留一个候选，并保留首条历史快照。
func _test_duplicate_history_rows_are_one_candidate() -> bool:
	var pool = CANDIDATE_POOL.new()
	var history: Array[Dictionary] = [
		{
			"original_sentence_id": "line-a",
			"tendency": "orthodox",
			"hit_count": 1,
			"first_hit_order": 1,
			"last_hit_order": 1,
		},
		{
			"original_sentence_id": &"line-a",
			"tendency": "orthodox",
			"hit_count": 2,
			"first_hit_order": 1,
			"last_hit_order": 3,
		},
	]
	var candidates: Array[Dictionary] = pool.build_from_normal_hit_history(history)
	if candidates.size() != 1 or int(candidates[0].get("hit_count", 0)) != 1:
		push_error("FO-02 应按字符串形式一致的原句 ID 去重并保留首条历史")
		return false
	return true


# 候选只从 HR-14 普通历史建立；复读与矛盾文本由其他入口处理，不作为候选来源。
func _test_only_normal_hit_history_enters_pool() -> bool:
	var hit_resolution = HIT_RESOLUTION.new(0.5, 0.0, 1.0)
	hit_resolution.record_normal_word_hit("line-a", "orthodox")
	hit_resolution.record_normal_word_hit("line-a", "orthodox")
	var pool = CANDIDATE_POOL.new()
	var candidates: Array[Dictionary] = pool.build_from_normal_hit_history(
		hit_resolution.get_normal_hit_history()
	)
	if candidates.size() != 1 or str(candidates[0].get("original_sentence_id", "")) != "line-a":
		push_error("FO-02 候选池只能包含 HR-14 提供的普通话语原句")
		return false
	if int(candidates[0].get("hit_count", 0)) != 2:
		push_error("FO-02 候选应保留 HR-14 聚合后的原句命中次数")
		return false
	return true


# 同倾向选择普通复读数最高者，矛盾复读数不参与比较。
func _test_highest_normal_repeat_per_tendency() -> bool:
	var pool = CANDIDATE_POOL.new()
	var history: Array[Dictionary] = [
		_make_history_entry("line-a", "orthodox"),
		_make_history_entry("line-b", "orthodox"),
		_make_history_entry("line-c", "heretical"),
		_make_history_entry("line-d", "absurd"),
	]
	var candidates: Array[Dictionary] = pool.build_from_normal_hit_history(history)
	var repeat_stats: RepeatGenerationStats = REPEAT_STATS.new()
	repeat_stats.record_generated(_make_repeat_plan(REPEAT_PLAN.RepeatType.NORMAL, &"line-a"), 2)
	repeat_stats.record_generated(_make_repeat_plan(REPEAT_PLAN.RepeatType.NORMAL, &"line-b"), 5)
	repeat_stats.record_generated(_make_repeat_plan(REPEAT_PLAN.RepeatType.NORMAL, &"line-c"), 3)
	repeat_stats.record_generated(_make_repeat_plan(REPEAT_PLAN.RepeatType.CONTRADICTION, &"line-a"), 10)
	var selected: Array[Dictionary] = pool.select_most_repeated_per_tendency(candidates, repeat_stats)
	if selected.size() != 3:
		push_error("FO-03 应为每种存在候选的倾向最多选出一句")
		return false
	var selected_by_tendency: Dictionary = {}
	for candidate: Dictionary in selected:
		selected_by_tendency[str(candidate.get("tendency", ""))] = str(
			candidate.get("original_sentence_id", "")
		)
	if (
		selected_by_tendency.get("orthodox", "") != "line-b"
		or selected_by_tendency.get("heretical", "") != "line-c"
		or selected_by_tendency.get("absurd", "") != "line-d"
	):
		push_error("FO-03 没有按每种倾向的实际普通复读数选择最高候选")
		return false
	return true


func _make_history_entry(original_sentence_id: String, tendency: String) -> Dictionary:
	return {
		"original_sentence_id": original_sentence_id,
		"tendency": tendency,
		"hit_count": 1,
		"first_hit_order": 1,
		"last_hit_order": 1,
	}


# 普通复读数相同时，最近命中优先级高于原句 ID 顺序。
func _test_latest_hit_breaks_repeat_tie() -> bool:
	var earlier_hit: Dictionary = _make_history_entry("line-a", "orthodox")
	earlier_hit["last_hit_order"] = 7
	var later_hit: Dictionary = _make_history_entry("line-z", "orthodox")
	later_hit["last_hit_order"] = 8
	var pool = CANDIDATE_POOL.new()
	var candidates: Array[Dictionary] = pool.build_from_normal_hit_history([earlier_hit, later_hit])
	var repeat_stats: RepeatGenerationStats = REPEAT_STATS.new()
	repeat_stats.record_generated(_make_repeat_plan(REPEAT_PLAN.RepeatType.NORMAL, &"line-a"), 2)
	repeat_stats.record_generated(_make_repeat_plan(REPEAT_PLAN.RepeatType.NORMAL, &"line-z"), 2)
	var selected: Array[Dictionary] = pool.select_most_repeated_per_tendency(candidates, repeat_stats)
	if selected.size() != 1 or str(selected[0].get("original_sentence_id", "")) != "line-z":
		push_error("FO-04 普通复读并列时应优先选择最近命中的原句")
		return false
	return true


# 普通复读数和最近命中顺序均相同时，按原句 ID 升序稳定裁决。
func _test_stable_sentence_id_breaks_final_tie() -> bool:
	var later_id: Dictionary = _make_history_entry("line-z", "orthodox")
	later_id["last_hit_order"] = 8
	var earlier_id: Dictionary = _make_history_entry("line-a", "orthodox")
	earlier_id["last_hit_order"] = 8
	var pool = CANDIDATE_POOL.new()
	var candidates: Array[Dictionary] = pool.build_from_normal_hit_history([later_id, earlier_id])
	var repeat_stats: RepeatGenerationStats = REPEAT_STATS.new()
	repeat_stats.record_generated(_make_repeat_plan(REPEAT_PLAN.RepeatType.NORMAL, &"line-a"), 2)
	repeat_stats.record_generated(_make_repeat_plan(REPEAT_PLAN.RepeatType.NORMAL, &"line-z"), 2)
	var selected: Array[Dictionary] = pool.select_most_repeated_per_tendency(candidates, repeat_stats)
	if selected.size() != 1 or str(selected[0].get("original_sentence_id", "")) != "line-a":
		push_error("FO-04 双层并列时应按稳定原句 ID 升序裁决")
		return false
	return true


func _make_repeat_plan(repeat_type: int, original_line_id: StringName) -> RepeatPlan:
	var plan: RepeatPlan = REPEAT_PLAN.new()
	plan.repeat_type = repeat_type
	plan.original_line_id = original_line_id
	return plan
