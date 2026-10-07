extends SceneTree


# 本卡只覆盖原关卡排序和缺章保留，编号随机源固定便于复现。
func _initialize() -> void:
	seed(1504)
	if not _test_entries_follow_original_order() or not _test_missing_chapters_keep_slots():
		quit(1)
		return
	print("PASS SC-04: 经文排序、缺章与全空圣典，共 2 项")
	quit(0)


# 故意乱序确认，公开读取结果仍按原关卡序号排列。
func _test_entries_follow_original_order() -> bool:
	var data: ScriptureData = ScriptureData.new()
	var catalog: LevelCatalog = _make_catalog()
	for level: LevelProfile in catalog.profiles:
		data.write_confirmed_oracle(level, _candidate(level))
	var ordered_entries: Array[ScriptureEntry] = data.get_ordered_entries()
	if ordered_entries.size() != 3 or ordered_entries[0].chapter_number != 1 or ordered_entries[1].chapter_number != 3 or ordered_entries[2].chapter_number != 5:
		push_error("SC-04 经文没有按原关卡序号排列")
		return false
	return true


# 中间关缺经文时保留 null 位置；全部没有经文时目录中的各章仍存在。
func _test_missing_chapters_keep_slots() -> bool:
	var data: ScriptureData = ScriptureData.new()
	var catalog: LevelCatalog = _make_catalog()
	data.write_confirmed_oracle(catalog.profiles[0], _candidate(catalog.profiles[0]))
	data.write_confirmed_oracle(catalog.profiles[1], _candidate(catalog.profiles[1]))
	var slots: Array[Dictionary] = data.get_chapter_slots(catalog)
	if slots.size() != 3 or slots[0]["entry"] == null or slots[1]["entry"] != null or slots[2]["entry"] == null:
		push_error("SC-04 缺章位置被删除或生成了虚构经文")
		return false
	if slots[0]["chapter_number"] != 1 or slots[1]["chapter_number"] != 3 or slots[2]["chapter_number"] != 5:
		push_error("SC-04 缺章造成原章号压缩")
		return false
	var empty_data: ScriptureData = ScriptureData.new()
	var empty_slots: Array[Dictionary] = empty_data.get_chapter_slots(catalog)
	if empty_slots.size() != 3:
		push_error("SC-04 全空圣典没有保留章节位置")
		return false
	for slot: Dictionary in empty_slots:
		if slot["entry"] != null:
			push_error("SC-04 全空圣典产生了经文")
			return false
	return true


# 使用非连续原序号验证读取不会把第 3、5 章压缩为第 2、3 章。
func _make_catalog() -> LevelCatalog:
	var catalog: LevelCatalog = LevelCatalog.new()
	for chapter: int in [5, 1, 3]:
		var level: LevelProfile = LevelProfile.new()
		level.level_id = "chapter_level_%d" % chapter
		level.level_order = chapter
		var speech: LevelSpeech = LevelSpeech.new()
		speech.original_sentence_id = "chapter_line_%d" % chapter
		speech.text = "测试章节原句"
		speech.tendency_id = "orthodox"
		level.normal_speech_pool.append(speech)
		catalog.profiles.append(level)
	return catalog


# 确认输入沿用生产方的稳定原句 ID 与倾向字段。
func _candidate(level: LevelProfile) -> Dictionary:
	var speech: LevelSpeech = level.normal_speech_pool[0]
	return {"original_sentence_id": speech.original_sentence_id, "tendency": speech.tendency_id}
