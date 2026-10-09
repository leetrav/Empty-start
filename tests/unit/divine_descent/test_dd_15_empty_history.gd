extends SceneTree


# DD-15 仅一个关键用例：无原始普通命中历史直接准备空态，数据均为 TEST_ONLY。
func _init() -> void:
	call_deferred("_run_test")


# 复读记录和圣典均不能补成普通命中历史；查询只消费首次冻结事实。
func _run_test() -> void:
	var run_data := SaveData.new()
	run_data.committed_normal_repeat_history_by_level = {
		"TEST_ONLY_dd15_level": {"TEST_ONLY_dd15_line": 3},
	}
	var session := DivineDescentSession.new()
	var passed: bool = not session.should_enter_empty_ending()
	passed = session.enter(run_data) and passed
	var frozen: Dictionary = session.get_entry_snapshot()
	passed = session.should_enter_empty_ending() and passed
	# 空态结果不会清除已保存圣典；同一关键用例验证圣典存在时仍按原始历史判断。
	var entry := ScriptureEntry.new()
	entry.level_id = &"TEST_ONLY_dd15_level"
	entry.original_line_id = &"TEST_ONLY_dd15_line"
	entry.original_line_text = "TEST_ONLY DD-15 scripture"
	entry.tendency_id = "orthodox"
	entry.chapter_number = 1
	entry.verse_number = 1
	run_data.scripture_data.entries.append(entry)
	var scripture_session := DivineDescentSession.new()
	passed = scripture_session.enter(run_data) and passed
	passed = scripture_session.should_enter_empty_ending() and passed
	passed = scripture_session.get_entry_snapshot()["scripture_entries"].size() == 1 and passed
	# 上游后续变化和 getter 副本修改均不改变首次空态决定。
	run_data.committed_normal_hit_history.append({"original_sentence_id": "TEST_ONLY_later"})
	var copy: Dictionary = session.get_entry_snapshot()
	copy["committed_normal_hit_history"].append({"original_sentence_id": "TEST_ONLY_copy"})
	passed = session.should_enter_empty_ending() and session.get_entry_snapshot() == frozen and passed
	if passed:
		print("PASS DD-15 empty original normal hit history prepares empty ending (1/1)")
	else:
		push_error("FAIL DD-15 empty original normal hit history")
	quit(0 if passed else 1)
