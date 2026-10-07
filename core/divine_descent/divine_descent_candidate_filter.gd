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
