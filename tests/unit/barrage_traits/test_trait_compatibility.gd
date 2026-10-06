extends SceneTree

const TraitSetScript = preload("res://systems/barrage_traits/barrage_trait_set.gd")

var _failures: int = 0
var _completed: int = 0


func _init() -> void:
	_test_unselectable_with_split()
	_test_unselectable_with_reflect()
	_test_split_with_trap()
	_test_split_with_repeat()

	if _failures > 0:
		push_error("BT-09: %d/%d case(s) failed." % [_failures, _completed])
		quit(1)
		return

	print("BT-09: %d cases passed." % _completed)
	quit(0)


# 不可选与分裂不能装在同一条弹幕上。
func _test_unselectable_with_split() -> void:
	var trait_ids: Array[StringName] = [TraitSetScript.UNSELECTABLE, TraitSetScript.SPLIT]
	_expect_compatibility(false, TraitSetScript.are_compatible(trait_ids), "unselectable + split")


# 不可选与反弹不能装在同一条弹幕上。
func _test_unselectable_with_reflect() -> void:
	var trait_ids: Array[StringName] = [TraitSetScript.UNSELECTABLE, TraitSetScript.REFLECT]
	_expect_compatibility(false, TraitSetScript.are_compatible(trait_ids), "unselectable + reflect")


# 分裂不兼容由对应系统识别为陷阱的弹幕类型。
func _test_split_with_trap() -> void:
	var trait_ids: Array[StringName] = [TraitSetScript.SPLIT]
	_expect_compatibility(false, TraitSetScript.are_compatible(trait_ids, true), "split + trap")


# 分裂不兼容复读弹幕类型；复读类别由复读系统提供。
func _test_split_with_repeat() -> void:
	var trait_ids: Array[StringName] = [TraitSetScript.SPLIT]
	_expect_compatibility(false, TraitSetScript.are_compatible(trait_ids, false, true), "split + repeat")


func _expect_compatibility(expected: bool, actual: bool, case_name: String) -> void:
	_completed += 1
	if actual == expected:
		print("PASS: %s" % case_name)
		return

	_failures += 1
	push_error("FAIL: %s; expected compatibility=%s, got %s." % [case_name, expected, actual])
