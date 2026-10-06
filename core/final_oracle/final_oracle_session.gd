class_name FinalOracleSession
extends RefCounted

signal opened(level_id: String, candidates: Array[Dictionary])

var _level_id: String = ""
var _display_candidates: Array[Dictionary] = []
var _open: bool = false


# 只接收已完成矛盾过渡的本场事实，使用现有候选池冻结一次展示列表。
func open_after_breakthrough(
	level_id: String,
	normal_hit_history: Array[Dictionary],
	repeat_stats: RepeatGenerationStats
) -> bool:
	if _open or level_id.is_empty() or repeat_stats == null:
		return false
	var pool := FinalOracleCandidatePool.new()
	var eligible: Array[Dictionary] = pool.build_from_normal_hit_history(normal_hit_history)
	var candidates: Array[Dictionary] = pool.fill_missing_tendency_candidates(eligible, repeat_stats)
	_display_candidates = pool.snapshot_for_display(candidates)
	_level_id = level_id
	_open = true
	opened.emit(_level_id, get_display_candidates())
	return true


func is_open() -> bool:
	return _open


func get_level_id() -> String:
	return _level_id


func get_display_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate: Dictionary in _display_candidates:
		result.append(candidate.duplicate(true))
	return result
