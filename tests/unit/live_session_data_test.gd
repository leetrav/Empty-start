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
	print("通过：开播观看人数正常计算与非负边界两项单元测试")
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
