extends SceneTree

const REPEAT_PLAN = preload("res://core/repeat/repeat_plan.gd")
const DELAY_QUEUE = preload("res://core/repeat/repeat_delay_queue.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	await process_frame
	if not _test_queue_retains_requests_with_capacity():
		quit(1)
		return
	if not _test_queue_discards_overflow():
		quit(1)
		return
	print("通过：普通复读队列容量保留与溢出丢弃两项单元测试")
	quit()


# 容量足够时，计划的所有普通复读都会进入待生成队列。
func _test_queue_retains_requests_with_capacity() -> bool:
	var queue: Object = DELAY_QUEUE.new(4)
	var plan: Resource = _make_normal_plan(3)
	var accepted_count: int = int(queue.call("enqueue_plan", plan))
	var wait_offsets: PackedFloat32Array = plan.get("wait_offsets_seconds")
	if accepted_count != 3 or wait_offsets.size() != 3:
		push_error("有剩余容量时普通复读计划没有完整入队")
		return false
	return true


# 剩余容量不足时只保留容量允许的请求，并丢弃超出部分。
func _test_queue_discards_overflow() -> bool:
	var queue: Object = DELAY_QUEUE.new(3)
	var first_plan: Resource = _make_normal_plan(2)
	var overflow_plan: Resource = _make_normal_plan(2)
	if int(queue.call("enqueue_plan", first_plan)) != 2:
		push_error("首个普通复读计划没有占用预期容量")
		return false
	var accepted_count: int = int(queue.call("enqueue_plan", overflow_plan))
	var wait_offsets: PackedFloat32Array = overflow_plan.get("wait_offsets_seconds")
	if accepted_count != 1 or wait_offsets.size() != 1:
		push_error("普通复读队列没有丢弃超出容量的部分")
		return false
	return true


func _make_normal_plan(repeat_count: int) -> Resource:
	var plan: Resource = REPEAT_PLAN.new()
	plan.set("repeat_type", 0)
	plan.set("planned_repeat_count", repeat_count)
	plan.set("original_line_id", &"line_capacity_fixture")
	plan.set("original_line_text", "容量测试原句")
	return plan
