extends SceneTree


# 本卡只保留一个关键用例：本场结算继续后选择正确的下一普通关。
func _init() -> void:
	if _test_continue_selects_next_normal_level():
		print("PASS RS-09：有下一关时返回 ADVANCED 并进入正确普通关，1/1")
		quit()
	else:
		push_error("FAIL RS-09：有下一关时未选择正确的普通关路线")
		quit(1)


# 临时乱序目录使用不连续序号，证明路由复用 LevelRunState 的顺序判断。
func _test_continue_selects_next_normal_level() -> bool:
	var first: LevelProfile = LevelProfile.new()
	first.level_id = "test_rs09_first"
	first.level_order = 1
	var next: LevelProfile = LevelProfile.new()
	next.level_id = "test_rs09_next"
	next.level_order = 3
	var catalog: LevelCatalog = LevelCatalog.new()
	catalog.profiles = [next, first]
	var run_state: LevelRunState = LevelRunState.new(catalog)
	var session: RestSession = RestSession.new()
	if not session.open_result({"level_id": first.level_id, "result_kind": "pk_win_unbroken"}):
		return false
	return (
		session.continue_to_next_level(run_state) == LevelRunState.CompletionResult.ADVANCED
		and run_state.get_current_level_profile() == next
	)
