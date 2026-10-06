extends SceneTree

const TENDENCY_STATE = preload("res://core/tendencies/tendency_state.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	await process_frame
	if not _test_highest_positive_remaining_tendency_is_secondary():
		quit(1)
		return
	if not _test_secondary_falls_back_to_primary_when_no_remaining_positive_score():
		quit(1)
		return
	print("通过：次要倾向最高正分与回退主导两项单元测试")
	quit()


# 次要倾向取主导以外的最高正分项。
func _test_highest_positive_remaining_tendency_is_secondary() -> bool:
	var tendency_state = TENDENCY_STATE.new()
	tendency_state.orthodox_total = 5
	tendency_state.heretical_total = 2
	tendency_state.absurd_total = 4
	if tendency_state.get_primary_tendency_id() != "orthodox":
		push_error("单一最高值没有成为主导倾向")
		return false
	if tendency_state.get_secondary_tendency_id() != "absurd":
		push_error("次要倾向没有选剩余项中的最高正分项")
		return false
	return true


# 主导以外两项均为零时，次要倾向与主导倾向相同。
func _test_secondary_falls_back_to_primary_when_no_remaining_positive_score() -> bool:
	var tendency_state = TENDENCY_STATE.new()
	tendency_state.orthodox_total = 4
	tendency_state.heretical_total = 0
	tendency_state.absurd_total = 0
	tendency_state.opening_identity_tendency_id = "heretical"
	if tendency_state.get_secondary_tendency_id() != "orthodox":
		push_error("剩余项没有正分时次要倾向没有回退到主导倾向")
		return false
	return true
