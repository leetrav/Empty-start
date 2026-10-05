class_name BarrageTraitSet
extends RefCounted

const OCCLUSION: StringName = &"occlusion"
const RETALIATION_COPY: StringName = &"retaliation_copy"
const FAKE_CARD: StringName = &"fake_card"
const UNSELECTABLE: StringName = &"unselectable"
const SPLIT: StringName = &"split"
const REFLECT: StringName = &"reflect"

var _trait_ids: Array[StringName] = []


# 给单条弹幕装配已定义的特性；重复或未知 ID 不会进入集合。
func add_trait(trait_id: StringName) -> bool:
	if not _is_supported_trait(trait_id) or _trait_ids.has(trait_id):
		return false

	_trait_ids.append(trait_id)
	return true


# 供攻击和结算系统按稳定 ID 查询特性。
func has_trait(trait_id: StringName) -> bool:
	return _trait_ids.has(trait_id)


# 只判断这条弹幕能否进入攻击目标集合，不处理整发落空。
func is_selectable() -> bool:
	return not has_trait(UNSELECTABLE)


# 返回副本，避免调用方绕过装配入口修改这条弹幕的特性。
func get_trait_ids() -> Array[StringName]:
	return _trait_ids.duplicate()


# 只接纳当前系统定义的稳定 ID，避免拼写差异产生无效特性。
func _is_supported_trait(trait_id: StringName) -> bool:
	return trait_id in [OCCLUSION, RETALIATION_COPY, FAKE_CARD, UNSELECTABLE, SPLIT, REFLECT]
