extends SceneTree

const CLASSIFIER = preload("res://core/ending/ending_identity_result_classifier.gd")
const OPENING_IDENTITY = preload("res://data/identity/identity_orthodox_placeholder.tres")


# 只运行 EN-05 要求的四类用例，失败时返回非零退出码。
func _initialize() -> void:
	var results: Array[bool] = [
		_test_no_effective_behavior(),
		_test_primary_tied(),
		_test_consistent(),
		_test_shifted(),
	]
	if results.has(false):
		quit(1)
		return
	print("PASS EN-05: 4 identity-result classes")
	quit(0)


# 全零同时存在并列与开局主导一致时，仍优先得到无行为类。
func _test_no_effective_behavior() -> bool:
	var state: TendencyState = _make_state(0, 0, 0)
	if CLASSIFIER.new().classify(state) != CLASSIFIER.NO_EFFECTIVE_BEHAVIOR:
		push_error("EN-05 全零结果未优先归为无行为类")
		return false
	print("PASS EN-05 no_effective_behavior")
	return true


# 最高分并列即使裁决后的主导与开局一致，也优先得到并列类。
func _test_primary_tied() -> bool:
	var state: TendencyState = _make_state(10, 10, 0)
	if CLASSIFIER.new().classify(state) != CLASSIFIER.PRIMARY_TIED:
		push_error("EN-05 最高分并列未优先归为并列类")
		return false
	print("PASS EN-05 primary_tied")
	return true


# 存在有效行为且唯一主导与开局身份对应倾向一致，得到一致类。
func _test_consistent() -> bool:
	var state: TendencyState = _make_state(10, 3, 0)
	if CLASSIFIER.new().classify(state) != CLASSIFIER.CONSISTENT:
		push_error("EN-05 开局与唯一主导一致时分类错误")
		return false
	print("PASS EN-05 consistent")
	return true


# 存在有效行为且唯一主导偏离开局身份对应倾向，得到偏移类。
func _test_shifted() -> bool:
	var state: TendencyState = _make_state(3, 10, 0)
	if CLASSIFIER.new().classify(state) != CLASSIFIER.SHIFTED:
		push_error("EN-05 开局与唯一主导不同未归为偏移类")
		return false
	print("PASS EN-05 shifted")
	return true


# 从真实身份 Resource 初始化参照，并通过三项倾向公开累计入口准备已提交结果。
func _make_state(orthodox: int, heretical: int, absurd: int) -> TendencyState:
	var state: TendencyState = TendencyState.new()
	state.initialize_from_identity_option(OPENING_IDENTITY)
	state.record_normal_speech_tendency("orthodox", orthodox)
	state.record_normal_speech_tendency("heretical", heretical)
	state.record_normal_speech_tendency("absurd", absurd)
	state.commit_attempt_tendency()
	return state
