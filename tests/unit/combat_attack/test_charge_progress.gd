extends SceneTree

const AttackChargeScript = preload("res://systems/combat_attack/attack_charge_progress.gd")

var _failures: int = 0
var _completed: int = 0


func _init() -> void:
	_test_charge_completes_without_a_target()
	_test_charge_continues_across_candidate_changes()

	if _failures > 0:
		push_error("CA-03: %d/%d case(s) failed." % [_failures, _completed])
		quit(1)
		return

	print("CA-03: %d cases passed." % _completed)
	quit(0)


# 蓄力状态不需要候选目标输入，因此没有目标也能达到配置时长。
func _test_charge_completes_without_a_target() -> void:
	var charge = AttackChargeScript.new(1.0)
	charge.advance(0.5, true)
	charge.advance(0.5, true)
	_expect(charge.is_fully_charged(), "charge completes without target")


# 准心移动或候选变化期间，连续按住只增加已有进度，不会清零。
func _test_charge_continues_across_candidate_changes() -> void:
	var charge = AttackChargeScript.new(1.0)
	charge.advance(0.25, true)
	var previous_progress: float = charge.get_progress()
	charge.advance(0.25, true)
	_expect(
		charge.get_progress() > previous_progress and is_equal_approx(charge.get_progress(), 0.5),
		"charge progress persists through candidate changes"
	)


func _expect(condition: bool, case_name: String) -> void:
	_completed += 1
	if condition:
		print("PASS: %s" % case_name)
		return

	_failures += 1
	push_error("FAIL: %s" % case_name)
