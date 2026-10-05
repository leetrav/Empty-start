extends SceneTree

const AttackChargeScript = preload("res://systems/combat_attack/attack_charge_progress.gd")

var _failures: int = 0


func _init() -> void:
	_test_undercharged_release_clears_progress()

	if _failures > 0:
		quit(1)
		return

	print("CA-04: 1 case passed.")
	quit(0)


# 松开时未满蓄力会重置进度，且纯状态对象不会产生攻击结果。
func _test_undercharged_release_clears_progress() -> void:
	var charge = AttackChargeScript.new(1.0)
	charge.advance(0.4, true)
	var canceled: bool = charge.cancel_if_undercharged()
	var passed: bool = canceled and is_equal_approx(charge.get_progress(), 0.0)
	if passed:
		print("PASS: undercharged release clears progress")
		return

	_failures += 1
	push_error("FAIL: undercharged release must clear progress without producing a shot")
