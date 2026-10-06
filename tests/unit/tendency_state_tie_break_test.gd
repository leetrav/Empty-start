extends SceneTree

const TENDENCY_STATE = preload("res://core/tendencies/tendency_state.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	await process_frame
	if not _test_opening_identity_wins_tie():
		quit(1)
		return
	if not _test_fixed_order_marks_tie():
		quit(1)
		return
	print("通过：主导倾向开局参照优先与固定顺序裁决两项单元测试")
	quit()


# 最高并列项包含开局身份倾向时，优先返回开局参照并标记并列。
func _test_opening_identity_wins_tie() -> bool:
	var tendency_state = TENDENCY_STATE.new()
	tendency_state.orthodox_total = 4
	tendency_state.heretical_total = 2
	tendency_state.absurd_total = 4
	tendency_state.opening_identity_tendency_id = "absurd"
	if tendency_state.get_primary_tendency_id() != "absurd" or not tendency_state.is_primary_tied():
		push_error("最高并列包含开局身份倾向时没有按参照优先裁决")
		return false
	return true


# 最高并列不含开局身份倾向时，按正统到荒谬顺序裁决并标记并列。
func _test_fixed_order_marks_tie() -> bool:
	var tendency_state = TENDENCY_STATE.new()
	tendency_state.orthodox_total = 5
	tendency_state.heretical_total = 5
	tendency_state.absurd_total = 1
	tendency_state.opening_identity_tendency_id = "absurd"
	if tendency_state.get_primary_tendency_id() != "orthodox" or not tendency_state.is_primary_tied():
		push_error("最高并列不含开局身份倾向时没有按固定顺序裁决")
		return false
	return true
