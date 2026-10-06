extends SceneTree

const HIT_RESOLUTION = preload("res://core/combat/hit_resolution.gd")
const CANDIDATE_POOL = preload("res://core/final_oracle/final_oracle_candidate_pool.gd")


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
	print("通过：FO-02 原句去重与普通历史候选边界")
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
