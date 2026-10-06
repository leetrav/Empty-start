class_name FinalOracleCandidatePool
extends RefCounted


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
