class_name EndingIdentityResultClassifier
extends RefCounted

const NO_EFFECTIVE_BEHAVIOR: StringName = &"no_effective_behavior"
const PRIMARY_TIED: StringName = &"primary_tied"
const CONSISTENT: StringName = &"consistent"
const SHIFTED: StringName = &"shifted"


# 按无行为、并列、一致、偏移的优先级分类；倾向判定全部读取 17 系统公开结果。
func classify(tendency_state: TendencyState) -> StringName:
	if tendency_state.has_no_effective_behavior():
		return NO_EFFECTIVE_BEHAVIOR
	if tendency_state.is_primary_tied():
		return PRIMARY_TIED
	# 开局参照由 Identify 确认时从 IdentityOption.tendency_id 写入，沿用周目保存值。
	if tendency_state.opening_identity_tendency_id == tendency_state.get_primary_tendency_id():
		return CONSISTENT
	return SHIFTED
