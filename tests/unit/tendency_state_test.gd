extends SceneTree

const TENDENCY_STATE = preload("res://core/tendencies/tendency_state.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	await process_frame
	if not _test_single_highest_is_primary():
		quit(1)
		return
	print("通过：单一最高累计值被选为主导倾向")
	quit()


# 只有一项严格高于其他累计值时，返回该项稳定 ID。
func _test_single_highest_is_primary() -> bool:
	var tendency_state = TENDENCY_STATE.new()
	tendency_state.orthodox_total = 2
	tendency_state.heretical_total = 5
	tendency_state.absurd_total = 3
	if tendency_state.get_primary_tendency_id() != "heretical":
		push_error("单一最高累计值没有成为主导倾向")
		return false
	return true
