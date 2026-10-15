class_name ContradictionWindowConfig
extends Resource

## Paradox 窗口与移动配置；固定候选规模由下方常量定义，不沿用进入前的狂热档位。
const PARADOX_TRUE_CANDIDATE_COUNT: int = 1
const PARADOX_FALSE_CANDIDATE_COUNT: int = 5
const PARADOX_CANDIDATE_COUNT: int = PARADOX_TRUE_CANDIDATE_COUNT + PARADOX_FALSE_CANDIDATE_COUNT

@export var duration_seconds: float = 10.0
@export var max_shots: int = 1
@export var generation_count_multiplier: float = 2.0
@export var generation_frequency_multiplier: float = 3.0
@export var movement_speed_multiplier: float = 2.5
## 六句逐渐减速的可调演出时长；当前初值用于运行，正式手感仍待策划验收。
@export_range(0.1, 8.0, 0.1) var ease_out_motion_duration_seconds: float = 2.0
## 归一化速度曲线：X 为运动进度，Y 为当前速度倍率。
@export var ease_out_motion_speed_curve: Curve
@export var shootable_during_motion: bool = true


# 为尚未接入正式演出表的配置提供平滑减速初值，仍可在资源 Inspector 调整。
func _init() -> void:
	if ease_out_motion_speed_curve != null:
		return
	ease_out_motion_speed_curve = Curve.new()
	ease_out_motion_speed_curve.add_point(Vector2(0.0, 1.0))
	ease_out_motion_speed_curve.add_point(Vector2(1.0, 0.0))
