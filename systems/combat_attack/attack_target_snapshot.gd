class_name AttackTargetSnapshot
extends RefCounted

var _target_instance_ids: Array[int] = []


# 在释放时复制候选实例 ID 并去重；之后候选列表的变化不会加入本发。
static func capture_at_release(current_candidates: Array[Node]) -> AttackTargetSnapshot:
	var snapshot := AttackTargetSnapshot.new()
	var seen_instance_ids: Dictionary = {}

	for target in current_candidates:
		if not is_instance_valid(target):
			continue

		var instance_id: int = target.get_instance_id()
		if seen_instance_ids.has(instance_id):
			continue

		seen_instance_ids[instance_id] = true
		snapshot._target_instance_ids.append(instance_id)

	return snapshot


# 返回 ID 副本，调用方不能修改已经冻结的本发目标集合。
func get_target_instance_ids() -> Array[int]:
	return _target_instance_ids.duplicate()
