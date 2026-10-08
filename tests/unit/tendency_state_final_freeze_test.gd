extends SceneTree


# 本卡只执行一个关键用例：真实 Session 冻结的倾向事实保持不变。
func _initialize() -> void:
	if not _test_frozen_tendency_remains_unchanged():
		quit(1)
		return
	print("PASS TT-11: 1 frozen-tendency remains-unchanged case")
	quit(0)


# 源 Resource 仍归 17；验证进入快照排除暂存，并隔离后续输入、提交及读取副本。
func _test_frozen_tendency_remains_unchanged() -> bool:
	var run_data: SaveData = SaveData.new()
	var state: TendencyState = run_data.tendency_state
	var identity: IdentityOption = IdentityOption.new()
	identity.tendency_id = "heretical"
	state.initialize_from_identity_option(identity)
	state.record_normal_speech_tendency("orthodox", 5)
	state.record_normal_speech_tendency("heretical", 5)
	state.record_normal_speech_tendency("absurd", 2)
	state.commit_attempt_tendency()
	state.record_normal_speech_tendency("absurd", 31)
	var session: DivineDescentSession = DivineDescentSession.new()
	if not session.enter(run_data):
		push_error("TT-11 正式终局进入失败")
		return false
	var expected: Dictionary = {
		"orthodox_total": 5,
		"heretical_total": 5,
		"absurd_total": 2,
		"opening_identity_tendency_id": "heretical",
		"primary_tendency_id": "heretical",
		"secondary_tendency_id": "orthodox",
		"is_primary_tied": true,
		"has_no_effective_behavior": false,
	}
	if session.get_entry_snapshot()["tendency_result"] != expected:
		push_error("TT-11 没有按已提交值和既有裁决固定结果，或混入了 attempt")
		return false
	if run_data.tendency_state != state or state.absurd_total != 2 or state.attempt_absurd_total != 31:
		push_error("TT-11 进入终局改写了源状态所有权或暂存")
		return false
	state.record_normal_speech_tendency("orthodox", 100)
	if session.get_entry_snapshot()["tendency_result"] != expected:
		push_error("TT-11 新普通话语暂存改变了冻结结果")
		return false
	state.commit_attempt_tendency()
	if state.get_primary_tendency_id() != "orthodox" or state.is_primary_tied():
		push_error("TT-11 验收输入没有实际改变源已提交结果")
		return false
	if session.get_entry_snapshot()["tendency_result"] != expected:
		push_error("TT-11 后续提交改变了冻结总值或主次 / 并列")
		return false
	# 源初始化依据与全零状态变化，也不能影响既有终局会话。
	var later_identity: IdentityOption = IdentityOption.new()
	later_identity.tendency_id = "absurd"
	state.initialize_from_identity_option(later_identity)
	if not state.has_no_effective_behavior() or state.opening_identity_tendency_id != "absurd":
		push_error("TT-11 验收输入没有实际改变源全零和身份依据")
		return false
	if session.get_entry_snapshot()["tendency_result"] != expected or run_data.tendency_state != state:
		push_error("TT-11 源身份依据 / 全零变化影响了冻结结果或所有权")
		return false
	var caller_copy: Dictionary = session.get_entry_snapshot()
	caller_copy["tendency_result"]["primary_tendency_id"] = "absurd"
	caller_copy["tendency_result"]["orthodox_total"] = 999
	if session.get_entry_snapshot()["tendency_result"] != expected or state.orthodox_total != 0:
		push_error("TT-11 调用方读取副本回写了冻结结果或源状态")
		return false
	if session.enter(run_data) or session.get_entry_snapshot()["tendency_result"] != expected:
		push_error("TT-11 重复进入替换了首次冻结结果")
		return false
	return true
