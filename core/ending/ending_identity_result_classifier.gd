class_name EndingIdentityResultClassifier
extends RefCounted

const NO_EFFECTIVE_BEHAVIOR: StringName = &"no_effective_behavior"
const PRIMARY_TIED: StringName = &"primary_tied"
const CONSISTENT: StringName = &"consistent"
const SHIFTED: StringName = &"shifted"


# 按无行为、并列、一致、偏移的优先级分类；倾向判定全部读取 17 系统公开结果。
func classify(tendency_state: TendencyState) -> StringName:
	return classify_frozen_result({
		"has_no_effective_behavior": tendency_state.has_no_effective_behavior(),
		"is_primary_tied": tendency_state.is_primary_tied(),
		"opening_identity_tendency_id": tendency_state.opening_identity_tendency_id,
		"primary_tendency_id": tendency_state.get_primary_tendency_id(),
	})


# 直接消费 19 的冻结事实；复用原分类顺序，空输入表示尚无最终结果。
func classify_frozen_result(tendency_result: Dictionary) -> StringName:
	if tendency_result.is_empty():
		return &""
	if bool(tendency_result.get("has_no_effective_behavior", false)):
		return NO_EFFECTIVE_BEHAVIOR
	if bool(tendency_result.get("is_primary_tied", false)):
		return PRIMARY_TIED
	if str(tendency_result.get("opening_identity_tendency_id", "")) == str(tendency_result.get("primary_tendency_id", "")):
		return CONSISTENT
	return SHIFTED
