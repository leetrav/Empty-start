extends SceneTree

const CONFIRMATION_STATE = preload("res://core/identity/identity_confirmation_state.gd")

func _init() -> void:
	print("开始身份确认锁定测试")
	if not _test_first_confirmation_succeeds():
		quit(1)
		return
	if not _test_second_confirmation_does_not_replace():
		quit(1)
		return
	print("通过：身份确认锁定两项单元测试")
	quit()

# 首次使用当前数据源中存在的身份 ID 时应锁定并可读取。
func _test_first_confirmation_succeeds() -> bool:
	var state = CONFIRMATION_STATE.new()
	var orthodox_id: StringName = &"identity_orthodox"
	var available_identity_ids: Array[StringName] = [orthodox_id]
	if not state.confirm_identity(orthodox_id, available_identity_ids):
		push_error("首次有效身份确认失败")
		return false
	if state.get_confirmed_identity_id() != orthodox_id or not state.has_confirmed_identity():
		push_error("首次确认后没有保留身份 ID")
		return false
	return true

# 已锁定后再提交其他有效身份时必须保留首次确认的 ID。
func _test_second_confirmation_does_not_replace() -> bool:
	var state = CONFIRMATION_STATE.new()
	var orthodox_id: StringName = &"identity_orthodox"
	var heretical_id: StringName = &"identity_heretical"
	var available_identity_ids: Array[StringName] = [orthodox_id, heretical_id]
	if not state.confirm_identity(orthodox_id, available_identity_ids):
		push_error("二次确认测试的初始身份设置失败")
		return false
	if state.confirm_identity(heretical_id, available_identity_ids):
		push_error("已确认身份仍接受了第二次身份更改")
		return false
	if state.get_confirmed_identity_id() != orthodox_id:
		push_error("第二次确认覆盖了原身份 ID")
		return false
	return true
