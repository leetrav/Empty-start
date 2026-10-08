## 神降临的圣典读取适配，正式经文与排序规则继续由 15 持有。
class_name DivineDescentScriptureInput
extends RefCounted


# 读取已提交经文快照，将原句字段对齐 DD-02；同句多章保留，加权由 DD-07 负责。
static func build_snapshot(run_data: SaveData) -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	if run_data == null or run_data.scripture_data == null:
		return snapshot
	for entry: ScriptureEntry in run_data.scripture_data.get_ordered_entries():
		snapshot.append({
			"level_id": entry.level_id,
			"streamer_name": entry.streamer_name,
			"original_sentence_id": str(entry.original_line_id),
			"original_sentence_text": entry.original_line_text,
			"tendency": entry.tendency_id,
			"chapter_number": entry.chapter_number,
			"verse_number": entry.verse_number,
		})
	return snapshot
