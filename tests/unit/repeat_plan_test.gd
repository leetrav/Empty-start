extends SceneTree

const REPEAT_PLAN = preload("res://core/repeat/repeat_plan.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	await process_frame
	if not _test_repeat_count_is_fixed():
		quit(1)
		return
	if not _test_settled_tier_is_fixed():
		quit(1)
		return
	print("通过：普通复读计划固定生成数量与结算档位两项单元测试")
	quit()


# 创建后外部配置变化不会改写计划中已复制的数量。
func _test_repeat_count_is_fixed() -> bool:
	var configured_count: int = 4
	var plan: Resource = REPEAT_PLAN.create_normal_hit_plan(
		&"line_fixture_01", "测试原句", 1, configured_count, 4.0
	)
	configured_count = 9
	if int(plan.get("planned_repeat_count")) != 4:
		push_error("普通复读计划没有固定创建时的生成数量")
		return false
	return true


# 创建后档位变化不会改写计划中保存的结算后档位。
func _test_settled_tier_is_fixed() -> bool:
	var settled_tier: int = 2
	var plan: Resource = REPEAT_PLAN.create_normal_hit_plan(
		&"line_fixture_02", "测试原句", settled_tier, 5, 6.0
	)
	settled_tier = 4
	if int(plan.get("generation_tier")) != 2:
		push_error("普通复读计划没有固定创建时的结算档位")
		return false
	return true
