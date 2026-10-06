extends SceneTree

const TargetSnapshotScript = preload("res://systems/combat_attack/attack_target_snapshot.gd")

var _failures: int = 0
var _completed: int = 0


func _init() -> void:
	_test_same_instance_is_recorded_once()
	_test_late_candidate_is_not_added()

	if _failures > 0:
		push_error("CA-05: %d/%d case(s) failed." % [_failures, _completed])
		quit(1)
		return

	print("CA-05: %d cases passed." % _completed)
	quit(0)


# 同一弹幕实例在候选列表重复出现时，快照只保存一个实例 ID。
func _test_same_instance_is_recorded_once() -> void:
	var target := Node.new()
	var target_id: int = target.get_instance_id()
	var candidates: Array[Node] = [target, target]
	var snapshot = TargetSnapshotScript.capture_at_release(candidates)
	var ids: Array[int] = snapshot.get_target_instance_ids()
	_expect(ids.size() == 1 and ids[0] == target_id, "same instance is recorded once")
	target.free()


# 释放后再加入候选源列表的目标不会改变已经复制出的快照。
func _test_late_candidate_is_not_added() -> void:
	var released_target := Node.new()
	var late_target := Node.new()
	var released_id: int = released_target.get_instance_id()
	var candidates: Array[Node] = [released_target]
	var snapshot = TargetSnapshotScript.capture_at_release(candidates)
	candidates.append(late_target)
	var ids: Array[int] = snapshot.get_target_instance_ids()
	_expect(ids.size() == 1 and ids[0] == released_id, "late candidate is not added")
	released_target.free()
	late_target.free()


func _expect(condition: bool, case_name: String) -> void:
	_completed += 1
	if condition:
		print("PASS: %s" % case_name)
		return

	_failures += 1
	push_error("FAIL: %s" % case_name)
