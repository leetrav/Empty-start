extends SceneTree

const TraitSetScript = preload("res://systems/barrage_traits/barrage_trait_set.gd")
const TraitResultScript = preload("res://systems/barrage_traits/barrage_trait_result.gd")

var _failures: int = 0
var _completed: int = 0


func _init() -> void:
	_test_reflect_precedes_occlusion()
	_test_occlusion_precedes_base_type()
	_test_base_type_when_no_priority_trait()

	if _failures > 0:
		push_error("BT-08: %d/%d case(s) failed." % [_failures, _completed])
		quit(1)
		return

	print("BT-08: %d cases passed." % _completed)
	quit(0)


# 反弹与遮挡同时存在时，只返回反弹结果。
func _test_reflect_precedes_occlusion() -> void:
	var trait_set = TraitSetScript.new()
	trait_set.add_trait(TraitSetScript.REFLECT)
	trait_set.add_trait(TraitSetScript.OCCLUSION)
	_expect_kind(trait_set, TraitResultScript.Kind.REFLECT, "reflect precedes occlusion")


# 没有反弹但存在遮挡时，遮挡覆盖基础类型。
func _test_occlusion_precedes_base_type() -> void:
	var trait_set = TraitSetScript.new()
	trait_set.add_trait(TraitSetScript.OCCLUSION)
	trait_set.add_trait(TraitSetScript.FAKE_CARD)
	_expect_kind(trait_set, TraitResultScript.Kind.OCCLUSION, "occlusion precedes base type")


# 没有反弹和遮挡时，保留目标自己的基础类型。
func _test_base_type_when_no_priority_trait() -> void:
	var trait_set = TraitSetScript.new()
	trait_set.add_trait(TraitSetScript.FAKE_CARD)
	_expect_kind(trait_set, TraitResultScript.Kind.FAKE_CARD, "base type is preserved")


func _expect_kind(trait_set: Object, expected_kind: int, case_name: String) -> void:
	_completed += 1
	var actual_kind: int = trait_set.get_hit_result().kind
	if actual_kind == expected_kind:
		print("PASS: %s" % case_name)
		return

	_failures += 1
	push_error("FAIL: %s; expected %d, got %d." % [case_name, expected_kind, actual_kind])
