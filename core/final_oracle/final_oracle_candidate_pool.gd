class_name FinalOracleCandidatePool
extends RefCounted

const _TENDENCY_ORDER: Array[String] = ["orthodox", "heretical", "absurd"]


# 从 HR-14 的普通命中快照按原句 ID 去重，保留首次出现的历史记录顺序。
func build_from_normal_hit_history(normal_hit_history: Array[Dictionary]) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var seen_sentence_ids: Dictionary = {}
	for history_entry: Dictionary in normal_hit_history:
		if not history_entry.has("original_sentence_id"):
			continue
		var original_sentence_id: Variant = history_entry["original_sentence_id"]
		if original_sentence_id == null:
			continue
		var stable_sentence_id: String = str(original_sentence_id)
		if stable_sentence_id.is_empty() or seen_sentence_ids.has(stable_sentence_id):
			continue
		seen_sentence_ids[stable_sentence_id] = true
		candidates.append(history_entry.duplicate(true))
	return candidates


# 每种有候选的倾向保留普通复读数最高的一句，并按最近命中和稳定原句 ID 裁决并列。
func select_most_repeated_per_tendency(
		candidates: Array[Dictionary], repeat_stats: RepeatGenerationStats
	) -> Array[Dictionary]:
	var best_candidates_by_tendency: Dictionary = {}
	var best_repeat_counts_by_tendency: Dictionary = {}
	for candidate: Dictionary in candidates:
		var tendency_id: String = str(candidate.get("tendency", ""))
		if not _TENDENCY_ORDER.has(tendency_id):
			continue
		var original_sentence_id: Variant = candidate.get("original_sentence_id")
		if original_sentence_id == null:
			continue
		var repeat_count: int = repeat_stats.get_normal_count(StringName(str(original_sentence_id)))
		var should_replace: bool = not best_candidates_by_tendency.has(tendency_id)
		if not should_replace:
			var best_repeat_count: int = int(best_repeat_counts_by_tendency[tendency_id])
			if repeat_count > best_repeat_count:
				should_replace = true
			elif repeat_count == best_repeat_count:
				var current_candidate: Dictionary = best_candidates_by_tendency[tendency_id]
				var candidate_last_hit_order: int = int(candidate.get("last_hit_order", 0))
				var current_last_hit_order: int = int(current_candidate.get("last_hit_order", 0))
				if candidate_last_hit_order > current_last_hit_order:
					should_replace = true
				elif candidate_last_hit_order == current_last_hit_order:
					should_replace = str(original_sentence_id) < str(
						current_candidate.get("original_sentence_id", "")
					)
		if should_replace:
			best_candidates_by_tendency[tendency_id] = candidate
			best_repeat_counts_by_tendency[tendency_id] = repeat_count

	var selected_candidates: Array[Dictionary] = []
	for tendency_id: String in _TENDENCY_ORDER:
		if best_candidates_by_tendency.has(tendency_id):
			selected_candidates.append(best_candidates_by_tendency[tendency_id].duplicate(true))
	return selected_candidates
