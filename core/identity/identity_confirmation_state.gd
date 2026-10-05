class_name IdentityConfirmationState
extends RefCounted

var _confirmed_identity_id: StringName = &""

# 首次确认只接受调用方从当前身份资源整理出的 ID；确认后拒绝后续更改。
func confirm_identity(identity_id: StringName, available_identity_ids: Array[StringName]) -> bool:
	if not _confirmed_identity_id.is_empty() or identity_id.is_empty():
		return false
	if not available_identity_ids.has(identity_id):
		return false
	_confirmed_identity_id = identity_id
	return true

# 读取首次确认后锁定的身份 ID。
func get_confirmed_identity_id() -> StringName:
	return _confirmed_identity_id

# 从已保存的身份 ID 派生确认状态，避免维护重复布尔值。
func has_confirmed_identity() -> bool:
	return not _confirmed_identity_id.is_empty()
