class_name EndingScriptureDisplayData
extends RefCounted

const STATUS_CONFIRMED_ORACLE: String = "confirmed_oracle"
const STATUS_NOT_FORMED_ORACLE: String = "not_formed_oracle"


# 复用 ScriptureData 的章节槽位，把正式经文和缺章转换为页面可读快照。
func build_from_scripture(
		scripture_data: ScriptureData, level_catalog: LevelCatalog
	) -> Array[Dictionary]:
	var display_rows: Array[Dictionary] = []
	if scripture_data == null or level_catalog == null:
		return display_rows

	for chapter_slot: Dictionary in scripture_data.get_chapter_slots(level_catalog):
		var entry: ScriptureEntry = chapter_slot.get("entry") as ScriptureEntry
		var row: Dictionary = {
			"level_id": chapter_slot.get("level_id", StringName()),
			"chapter_number": int(chapter_slot.get("chapter_number", 0)),
			"verse_number": entry.verse_number if entry != null else 0,
			"streamer_name": entry.streamer_name if entry != null else "",
			"original_line_id": entry.original_line_id if entry != null else StringName(),
			"original_line_text": entry.original_line_text if entry != null else "",
			"tendency_id": entry.tendency_id if entry != null else "",
			"has_oracle": entry != null,
			"status": STATUS_CONFIRMED_ORACLE if entry != null else STATUS_NOT_FORMED_ORACLE,
		}
		display_rows.append(row)
	return display_rows
