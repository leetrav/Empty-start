extends SceneTree

const TENDENCY_STATE = preload("res://core/tendencies/tendency_state.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	await process_frame
	if not _test_all_zero_uses_opening_tendency():
		quit(1)
		return
	print("通过：全零时主导 / 次要沿用开局倾向并标记无有效行为")
	quit()


# 全零时两项结果沿用开局参照，并给下游提供无有效行为标记。
func _test_all_zero_uses_opening_tendency() -> bool:
	var tendency_state = TENDENCY_STATE.new()
	tendency_state.orthodox_total = 0
	tendency_state.heretical_total = 0
	tendency_state.absurd_total = 0
	tendency_state.opening_identity_tendency_id = "heretical"
	if (
		tendency_state.get_primary_tendency_id() != "heretical"
		or tendency_state.get_secondary_tendency_id() != "heretical"
		or not tendency_state.has_no_effective_behavior()
	):
		push_error("三项累计全零时没有沿用开局倾向或无行为标记")
		return false
	return true
