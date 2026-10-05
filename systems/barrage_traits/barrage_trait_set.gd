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


# 把这条弹幕标记为水军复制品，后续 UI 可读取同一标记。
func mark_as_retaliation_copy() -> bool:
	return add_trait(RETALIATION_COPY)


# 供 UI 判断是否显示反击标记。
func is_retaliation_copy() -> bool:
	return has_trait(RETALIATION_COPY)


# 复制品不再触发复制，避免复制链继续扩散。
func can_trigger_copy() -> bool:
	return not is_retaliation_copy()


# 只判断这条弹幕能否进入攻击目标集合，不处理整发落空。
func is_selectable() -> bool:
	return not has_trait(UNSELECTABLE)


# 把遮挡特性转换成结算可读取的目标结果；具体异常优先级由 BT-08 统一处理。
func get_hit_result() -> BarrageTraitResult:
	if has_trait(OCCLUSION):
		return BarrageTraitResult.new(BarrageTraitResult.Kind.OCCLUSION)
	if has_trait(FAKE_CARD):
		return BarrageTraitResult.new(BarrageTraitResult.Kind.FAKE_CARD)
	if has_trait(RETALIATION_COPY):
		return BarrageTraitResult.new(BarrageTraitResult.Kind.RETALIATION_COPY)

	return BarrageTraitResult.new()


# 返回副本，避免调用方绕过装配入口修改这条弹幕的特性。
func get_trait_ids() -> Array[StringName]:
	return _trait_ids.duplicate()


# 只接纳当前系统定义的稳定 ID，避免拼写差异产生无效特性。
func _is_supported_trait(trait_id: StringName) -> bool:
	return trait_id in [OCCLUSION, RETALIATION_COPY, FAKE_CARD, UNSELECTABLE, SPLIT, REFLECT]
