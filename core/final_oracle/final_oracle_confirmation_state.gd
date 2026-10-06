class_name FinalOracleConfirmationState
extends RefCounted

signal confirmation_committed(run_data: SaveData, level_id: String, candidate: Dictionary)

var _run_data: SaveData
var _confirmed_candidates_by_level: Dictionary = {}


# 本状态实例绑定一个当前周目；调用方应在该周目内复用同一实例。
func _init(run_data: SaveData) -> void:
	_run_data = run_data


# 手动选择和超时自动选择共用此入口；同一周目同一关卡只固定并广播首次结果。
func confirm_selection(level_id: String, candidate: Dictionary) -> bool:
	if _run_data == null or level_id.is_empty() or candidate.is_empty():
		return false
	if _confirmed_candidates_by_level.has(level_id):
		return false

	var candidate_snapshot: Dictionary = candidate.duplicate(true)
	_confirmed_candidates_by_level[level_id] = candidate_snapshot
	confirmation_committed.emit(_run_data, level_id, candidate_snapshot.duplicate(true))
	return true


# 重复打开流程时返回首次确认的固定候选快照。
func get_confirmed_selection(level_id: String) -> Dictionary:
	if not _confirmed_candidates_by_level.has(level_id):
		return {}
	return _confirmed_candidates_by_level[level_id].duplicate(true)
