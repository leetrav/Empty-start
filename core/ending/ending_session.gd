class_name EndingSession
extends RefCounted

const MAIN_ART: EndingMainArtConfig = preload("res://data/ending/ending_main_art_config.tres")
const RELIGION_NAME: EndingReligionNameConfig = preload("res://data/ending/ending_religion_name_config.tres")
const JUDGEMENT_TEXT: EndingJudgementTextConfig = preload("res://data/ending/ending_judgement_text_config.tres")

var _final_snapshot: Dictionary = {}
var _display_snapshot: Dictionary = {}


# 首次接收已进入的神降临事实，组合一次显示结果；实际转场仍由外层流程负责。
func receive_final_state(
		session: DivineDescentSession, level_catalog: LevelCatalog,
		main_art_config: EndingMainArtConfig = MAIN_ART,
		religion_name_config: EndingReligionNameConfig = RELIGION_NAME,
		judgement_text_config: EndingJudgementTextConfig = JUDGEMENT_TEXT
	) -> bool:
	if is_received() or session == null or not session.is_entered() or level_catalog == null:
		return false
	var entry: Dictionary = session.get_entry_snapshot()
	_final_snapshot = {
		"tendency_result": entry["tendency_result"],
		"scripture_entries": entry["scripture_entries"],
		"identity_id": entry["identity_id"],
		"streamer_name": entry["streamer_name"],
	}
	_display_snapshot = EndingDisplayData.new().build_from_frozen_tendency(
		_final_snapshot["tendency_result"], _read_scripture_copy(_final_snapshot["scripture_entries"]),
		level_catalog, main_art_config, religion_name_config, judgement_text_config
	)
	return true


# 接收状态由首次快照派生，重复调用不能替换结果。
func is_received() -> bool:
	return not _final_snapshot.is_empty()


# 返回独立事实副本，身份、姓名及经文仍是进入终局时的依据。
func get_final_snapshot() -> Dictionary:
	return _final_snapshot.duplicate(true)


# 页面刷新只取既有显示结果，不重新查询周目历史或章节目录。
func get_display_data() -> Dictionary:
	return _display_snapshot.duplicate(true)


# 将冻结经文投影成私有读取副本，复用 15 的排序 / 缺章规则，沿用已有固定节号。
func _read_scripture_copy(entries: Array) -> ScriptureData:
	var scripture: ScriptureData = ScriptureData.new()
	for frozen: Dictionary in entries:
		var entry: ScriptureEntry = ScriptureEntry.new()
		entry.level_id = StringName(frozen["level_id"])
		entry.streamer_name = str(frozen["streamer_name"])
		entry.original_line_id = StringName(frozen["original_sentence_id"])
		entry.original_line_text = str(frozen["original_sentence_text"])
		entry.tendency_id = str(frozen["tendency"])
		entry.chapter_number = int(frozen["chapter_number"])
		entry.verse_number = int(frozen["verse_number"])
		scripture.entries.append(entry)
	return scripture
