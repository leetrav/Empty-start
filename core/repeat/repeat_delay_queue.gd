class_name RepeatDelayQueue
extends RefCounted

const DELAY_CONFIG: RepeatDelayConfig = preload("res://data/repeat/repeat_delay_config.tres")

var _random_generator: RandomNumberGenerator = RandomNumberGenerator.new()
var _pending_items: Array[Dictionary] = []
var _maximum_pending_normal_count: int
var _generation_stats: RepeatGenerationStats = RepeatGenerationStats.new()


func _init(maximum_pending_normal_count: int) -> void:
	# 容量由调用方读取数值配置后传入；随机源只在普通计划入队时抽取等待时间。
	_maximum_pending_normal_count = maxi(maximum_pending_normal_count, 0)
	_random_generator.randomize()


# 把普通复读计划拆成多条各自等待的单条生成请求。
func enqueue_plan(plan: RepeatPlan) -> int:
	if plan == null or plan.repeat_type != RepeatPlan.RepeatType.NORMAL or plan.planned_repeat_count <= 0:
		return 0
	if DELAY_CONFIG.minimum_delay_seconds < 0.0 or DELAY_CONFIG.maximum_delay_seconds < DELAY_CONFIG.minimum_delay_seconds:
		push_error("RepeatDelayQueue: configured delay range is invalid.")
		return 0

	var available_capacity: int = maxi(_maximum_pending_normal_count - _pending_items.size(), 0)
	var accepted_count: int = mini(plan.planned_repeat_count, available_capacity)
	var wait_offsets: PackedFloat32Array = PackedFloat32Array()
	for _index in range(accepted_count):
		var delay_seconds: float = _random_generator.randf_range(
			DELAY_CONFIG.minimum_delay_seconds,
			DELAY_CONFIG.maximum_delay_seconds
		)
		wait_offsets.append(delay_seconds)

		var request_plan: RepeatPlan = plan.duplicate(true) as RepeatPlan
		request_plan.planned_repeat_count = 1
		request_plan.wait_offsets_seconds = PackedFloat32Array([delay_seconds])
		_pending_items.append({"remaining_seconds": delay_seconds, "plan": request_plan})

	plan.wait_offsets_seconds = wait_offsets
	return accepted_count


# 推进所有等待项，并返回到期的单条计划副本供调用方生成。
func advance(delta_seconds: float) -> Array[RepeatPlan]:
	var ready_requests: Array[RepeatPlan] = []
	var remaining_items: Array[Dictionary] = []
	var elapsed_seconds: float = maxf(delta_seconds, 0.0)

	for pending_item in _pending_items:
		var remaining_seconds: float = float(pending_item["remaining_seconds"]) - elapsed_seconds
		if remaining_seconds <= 0.0:
			ready_requests.append(pending_item["plan"] as RepeatPlan)
		else:
			pending_item["remaining_seconds"] = remaining_seconds
			remaining_items.append(pending_item)

	_pending_items = remaining_items
	return ready_requests


# 到期后请求 BarrageGeneration 生成；容量暂满的请求留在队列等位置释放。
func advance_and_dispatch(delta_seconds: float, barrage_area: BarrageArea) -> int:
	if barrage_area == null:
		return 0

	var generated_count: int = 0
	var retry_requests: Array[RepeatPlan] = []
	for plan: RepeatPlan in advance(delta_seconds):
		var repeat_view: BarrageView = barrage_area.spawn_repeat_barrage(plan)
		if repeat_view == null:
			retry_requests.append(plan)
			continue
		_generation_stats.record_generated(plan, 1)
		generated_count += 1

	for plan: RepeatPlan in retry_requests:
		_pending_items.append({"remaining_seconds": 0.0, "plan": plan})
	return generated_count


# 向后续统计读取方提供由本队列维护的实际生成数据。
func get_generation_stats() -> RepeatGenerationStats:
	return _generation_stats


# 转入矛盾阶段时清空尚未到期的普通复读，避免阶段结束后迟到。
func clear_normal_queue() -> int:
	var cleared_count: int = _pending_items.size()
	_pending_items.clear()
	return cleared_count
