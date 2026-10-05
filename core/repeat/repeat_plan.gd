class_name RepeatPlan
extends Resource

enum RepeatType { NORMAL, CONTRADICTION }

@export var original_line_id: StringName = &""
@export var original_line_text: String = ""
@export var repeat_type: RepeatType = RepeatType.NORMAL
@export var planned_repeat_count: int = 0
@export var generation_tier: int = 0
@export var lifetime_seconds: float = 0.0

# 每个复读条目的等待偏移；延迟队列负责按配置生成并读取这些时间。
@export var wait_offsets_seconds: PackedFloat32Array = PackedFloat32Array()
