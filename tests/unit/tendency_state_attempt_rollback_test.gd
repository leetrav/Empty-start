extends SceneTree

const TENDENCY_STATE = preload("res://core/tendencies/tendency_state.gd")


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	await process_frame
	var tendency_state: TendencyState = TENDENCY_STATE.new()
	tendency_state.orthodox_total = 7
	tendency_state.heretical_total = 11
	tendency_state.absurd_total = 13
	tendency_state.record_normal_speech_tendency("orthodox", 2)
	tendency_state.record_normal_speech_tendency("heretical", 3)
	tendency_state.record_normal_speech_tendency("absurd", 5)
	tendency_state.rollback_attempt_tendency()

	var attempts_cleared: bool = tendency_state.attempt_orthodox_total == 0 and tendency_state.attempt_heretical_total == 0 and tendency_state.attempt_absurd_total == 0
	var committed_preserved: bool = tendency_state.orthodox_total == 7 and tendency_state.heretical_total == 11 and tendency_state.absurd_total == 13
	var passed: bool = attempts_cleared and committed_preserved
	if passed:
		print("PASS: TT-04 失败回滚清空本场倾向并保留已提交累计值。")
	else:
		push_error("FAIL: TT-04 失败回滚改变了错误的数据范围。")
	quit(0 if passed else 1)
