class_name RepeatGenerationStats
extends Resource

@export var normal_counts_by_line_id: Dictionary = {}
@export var contradiction_counts_by_line_id: Dictionary = {}


# 按计划类型把弹幕生成系统确认的实际数量归到原句 ID。
func record_generated(plan: RepeatPlan, actual_generated_count: int) -> void:
	if plan == null or plan.original_line_id.is_empty() or actual_generated_count <= 0:
		return

	match plan.repeat_type:
		RepeatPlan.RepeatType.NORMAL:
			_increment_count(normal_counts_by_line_id, plan.original_line_id, actual_generated_count)
		RepeatPlan.RepeatType.CONTRADICTION:
			_increment_count(contradiction_counts_by_line_id, plan.original_line_id, actual_generated_count)
		_:
			return


# 读取指定原句已生成的普通复读数量。
func get_normal_count(original_line_id: StringName) -> int:
	return int(normal_counts_by_line_id.get(original_line_id, 0))


# 读取指定原句已生成的矛盾复读数量。
func get_contradiction_count(original_line_id: StringName) -> int:
	return int(contradiction_counts_by_line_id.get(original_line_id, 0))


func _increment_count(counts: Dictionary, original_line_id: StringName, amount: int) -> void:
	counts[original_line_id] = int(counts.get(original_line_id, 0)) + amount
