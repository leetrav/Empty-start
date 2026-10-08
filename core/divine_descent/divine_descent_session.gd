class_name DivineDescentSession
extends RefCounted

var _entry_snapshot: Dictionary = {}


# 由普通关卡完成流程调用一次；冻结已提交事实，不提交或改变上游暂存。
func enter(run_data: SaveData) -> bool:
	if is_entered() or run_data == null or run_data.tendency_state == null:
		return false
	var hit_history: Array[Dictionary] = run_data.get_committed_normal_hit_history()
	var repeat_counts: Dictionary = RepeatGenerationStats.get_committed_normal_counts_by_line_id(run_data)
	var candidate_filter := DivineDescentCandidateFilter.new()
	_entry_snapshot = {
		"tendency_result": _snapshot_committed_tendency(run_data.tendency_state),
		"scripture_entries": DivineDescentScriptureInput.build_snapshot(run_data),
		"committed_normal_hit_history": hit_history,
		"normal_repeat_counts_by_line_id": repeat_counts,
		"history_candidates": candidate_filter.build_history_candidates(hit_history, repeat_counts),
		"assimilation_content": DivineDescentAssimilationInput.build_snapshot(run_data),
	}
	return true


# 快照建立后即为已进入；再次调用 enter 不替换首次结果。
func is_entered() -> bool:
	return not _entry_snapshot.is_empty()


# 后续演出只读取独立副本，避免调用方回写会话内部的冻结事实。
func get_entry_snapshot() -> Dictionary:
	return _entry_snapshot.duplicate(true)


# 倾向事实及裁决规则归 17；19 只复制已提交值与公开判定结果，排除 attempt 暂存。
func _snapshot_committed_tendency(state: TendencyState) -> Dictionary:
	return {
		"orthodox_total": state.orthodox_total,
		"heretical_total": state.heretical_total,
		"absurd_total": state.absurd_total,
		"opening_identity_tendency_id": state.opening_identity_tendency_id,
		"primary_tendency_id": state.get_primary_tendency_id(),
		"secondary_tendency_id": state.get_secondary_tendency_id(),
		"is_primary_tied": state.is_primary_tied(),
		"has_no_effective_behavior": state.has_no_effective_behavior(),
	}
