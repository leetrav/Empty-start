extends SceneTree

const LIVE_SESSION_DATA = preload("res://core/live_data/live_session_data.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	await process_frame
	if not _test_normal_opening_viewers():
		quit(1)
		return
	if not _test_opening_viewers_are_non_negative():
		quit(1)
		return
	if not _test_first_pk_win_fan_settlement():
		quit(1)
		return
	if not _test_repeated_pk_win_does_not_add_fans():
		quit(1)
		return
	print("通过：开播人数两项与 PK 胜利粉丝结算两项，共四项单元测试")
	quit()


# 按本次传入的倍率计算并保存开播观看人数。
func _test_normal_opening_viewers() -> bool:
	var live_session = LIVE_SESSION_DATA.new()
	live_session.initialize_session(81)
	if live_session.set_opening_viewers(0.75) != 60:
		push_error("正常倍率没有按粉丝数计算开播观看人数")
		return false
	return true


# 负粉丝数产生负乘积时，最终观看人数保持为 0。
func _test_opening_viewers_are_non_negative() -> bool:
	var live_session = LIVE_SESSION_DATA.new()
	live_session.initialize_session(-10)
	if live_session.set_opening_viewers(1.25) != 0:
		push_error("开播观看人数负数边界没有归零")
		return false
	return true


# 首次胜利提交配置增量；独立周目持有独立的结算记录。
func _test_first_pk_win_fan_settlement() -> bool:
	var live_session = LIVE_SESSION_DATA.new()
	live_session.initialize_session(20)
	if not live_session.commit_pk_win_fans(&"level_01", 7) or live_session.fan_count != 27:
		push_error("首次 PK 胜利没有增加配置的粉丝数")
		return false
	var next_run = LIVE_SESSION_DATA.new()
	if not next_run.commit_pk_win_fans(&"level_01", 7) or next_run.fan_count != 7:
		push_error("新周目被上一周目的结算记录阻止")
		return false
	return true


# 重复提交和重新开播都不能为同一关卡再次加粉。
func _test_repeated_pk_win_does_not_add_fans() -> bool:
	var live_session = LIVE_SESSION_DATA.new()
	live_session.initialize_session(20)
	live_session.commit_pk_win_fans(&"level_01", 7)
	if live_session.commit_pk_win_fans(&"level_01", 7) or live_session.fan_count != 27:
		push_error("重复提交 PK 胜利再次增加了粉丝")
		return false
	live_session.initialize_session(live_session.fan_count)
	if live_session.commit_pk_win_fans(&"level_01", 99) or live_session.fan_count != 27:
		push_error("重新开播清除了同一关卡的粉丝结算记录")
		return false
	return true
