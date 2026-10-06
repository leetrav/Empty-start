extends SceneTree

const REPEAT_PLAN = preload("res://core/repeat/repeat_plan.gd")
const REPEAT_STATS = preload("res://core/repeat/repeat_generation_stats.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	await process_frame
	if not _test_normal_generation_updates_only_normal_stats():
		quit(1)
		return
	if not _test_contradiction_generation_updates_only_contradiction_stats():
		quit(1)
		return
	print("通过：普通与矛盾复读实际生成统计两项单元测试")
	quit()


# 普通计划只累计弹幕生成系统报告的实际普通数量。
func _test_normal_generation_updates_only_normal_stats() -> bool:
	var stats: Resource = REPEAT_STATS.new()
	var plan: Resource = _make_plan(REPEAT_PLAN.RepeatType.NORMAL, &"normal_line", 8)
	stats.call("record_generated", plan, 3)
	if int(stats.call("get_normal_count", &"normal_line")) != 3:
		push_error("普通复读统计没有记录实际生成数量")
		return false
	if int(stats.call("get_contradiction_count", &"normal_line")) != 0:
		push_error("普通复读错误地增加了矛盾统计")
		return false
	return true


# 矛盾计划只累计实际矛盾数量，不能污染普通计数。
func _test_contradiction_generation_updates_only_contradiction_stats() -> bool:
	var stats: Resource = REPEAT_STATS.new()
	var plan: Resource = _make_plan(REPEAT_PLAN.RepeatType.CONTRADICTION, &"contradiction_line", 8)
	stats.call("record_generated", plan, 2)
	if int(stats.call("get_contradiction_count", &"contradiction_line")) != 2:
		push_error("矛盾复读统计没有记录实际生成数量")
		return false
	if int(stats.call("get_normal_count", &"contradiction_line")) != 0:
		push_error("矛盾复读错误地增加了普通统计")
		return false
	return true


func _make_plan(repeat_type: int, line_id: StringName, planned_count: int) -> Resource:
	var plan: Resource = REPEAT_PLAN.new()
	plan.set("repeat_type", repeat_type)
	plan.set("original_line_id", line_id)
	plan.set("planned_repeat_count", planned_count)
	return plan
