## 神降临未来的历史候选入口只接收三项倾向原句；普通 neutral 历史仍留在存档中。
class_name DivineDescentCandidateFilter
extends RefCounted

const _ELIGIBLE_TENDENCIES: Array[String] = ["orthodox", "heretical", "absurd"]


static func filter_three_tendency_history(committed_history: Array[Dictionary]) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	for entry: Dictionary in committed_history:
		if not _ELIGIBLE_TENDENCIES.has(str(entry.get("tendency", ""))):
			continue
		var sentence_id: String = str(entry.get("original_sentence_id", ""))
		if sentence_id.is_empty():
			continue
		eligible.append(entry.duplicate(true))
	return eligible


# 复用三项倾向边界，把已提交历史按稳定原句 ID 汇总成终局候选。
func build_history_candidates(committed_history: Array[Dictionary]) -> Array[Dictionary]:
	var eligible_history: Array[Dictionary] = filter_three_tendency_history(committed_history)
	var candidates_by_sentence_id: Dictionary = {}
	var candidate_order: Array[String] = []

	for history_entry: Dictionary in eligible_history:
		var sentence_id: String = str(history_entry.get("original_sentence_id", ""))
		if sentence_id.is_empty():
			continue

		if not candidates_by_sentence_id.has(sentence_id):
			candidates_by_sentence_id[sentence_id] = {
				"original_sentence_id": sentence_id,
				"original_sentence_text": str(history_entry.get("original_sentence_text", "")),
				"tendency": str(history_entry.get("tendency", "")),
				"hit_count": 0,
				"normal_repeat_count": 0,
				"first_committed_hit_order": int(history_entry.get("first_committed_hit_order", 0)),
			}
			candidate_order.append(sentence_id)

		var candidate: Dictionary = candidates_by_sentence_id[sentence_id]
		candidate["hit_count"] = int(candidate["hit_count"]) + _read_positive_count(
			history_entry, "hit_count"
		)
		candidate["normal_repeat_count"] = int(candidate["normal_repeat_count"]) + _read_positive_count(
			history_entry, "normal_repeat_count", "repeat_count"
		)
		if str(candidate.get("original_sentence_text", "")).is_empty():
			candidate["original_sentence_text"] = str(history_entry.get("original_sentence_text", ""))
		var first_order: int = int(history_entry.get("first_committed_hit_order", 0))
		if first_order > 0 and (
			int(candidate.get("first_committed_hit_order", 0)) <= 0
			or first_order < int(candidate["first_committed_hit_order"])
		):
			candidate["first_committed_hit_order"] = first_order

	var candidates: Array[Dictionary] = []
	for sentence_id: String in candidate_order:
		candidates.append((candidates_by_sentence_id[sentence_id] as Dictionary).duplicate(true))
	return candidates


# 读取提交记录中的非负计数；缺少字段时按零处理，兼容旧历史快照。
static func _read_positive_count(
		entry: Dictionary, primary_key: String, fallback_key: String = ""
) -> int:
	if entry.has(primary_key):
		return maxi(int(entry.get(primary_key, 0)), 0)
	if not fallback_key.is_empty() and entry.has(fallback_key):
		return maxi(int(entry.get(fallback_key, 0)), 0)
	return 0
