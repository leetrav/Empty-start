extends SceneTree


# 本卡只保留一个关键用例：末关结算继续后选择普通关全部完成的终局路线。
func _init() -> void:
	if _test_last_rest_selects_terminal_route():
		print("PASS RS-10：全部普通关完成时选择终局路线，1/1")
		quit()
	else:
		push_error("FAIL RS-10：末关继续未返回终局路线")
		quit(1)


# 单关临时目录的首次完成返回已有 ALL_NORMAL_LEVELS_COMPLETED，不另建路线协议。
func _test_last_rest_selects_terminal_route() -> bool:
	var level: LevelProfile = LevelProfile.new()
	level.level_id = "test_rs10_last"
	level.level_order = 1
	var catalog: LevelCatalog = LevelCatalog.new()
	catalog.profiles = [level]
	var run_state: LevelRunState = LevelRunState.new(catalog)
	var rest: RestSession = RestSession.new()
	if not rest.open_result({"level_id": level.level_id, "result_kind": "pk_win_unbroken"}):
		return false
	return (
		rest.continue_to_next_level(run_state) == LevelRunState.CompletionResult.ALL_NORMAL_LEVELS_COMPLETED
		and run_state.is_all_normal_levels_completed()
	)
