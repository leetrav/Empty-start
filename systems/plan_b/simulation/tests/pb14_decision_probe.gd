extends "res://systems/plan_b/simulation/plan_b_unit_simulation.gd"

var steering_call_count: int = 0
var steering_calls_by_id: Dictionary = {}


## 仅供 PB-14 smoke 统计决策频率；生产模拟器仍调用同一基类实现。
func _get_steering(unit: PlanBUnit, nearby_units: Array[PlanBUnit]) -> Dictionary:
	steering_call_count += 1
	steering_calls_by_id[unit.unit_id] = int(steering_calls_by_id.get(unit.unit_id, 0)) + 1
	return super._get_steering(unit, nearby_units)
