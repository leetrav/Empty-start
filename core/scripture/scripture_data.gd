class_name ScriptureData
extends Resource

const VERSE_CONFIG: ScriptureVerseConfig = preload("res://data/scripture/verse_number_config.tres")

@export var entries: Array[ScriptureEntry] = []


# 由周目组合方绑定真实神谕确认事件，关卡来源信息继续读取关卡目录。
func bind_confirmation_state(confirmation_state: FinalOracleConfirmationState, level_catalog: LevelCatalog) -> void:
	if confirmation_state == null or level_catalog == null:
		return
	var callback: Callable = _on_confirmation_committed.bind(level_catalog)
	if not confirmation_state.confirmation_committed.is_connected(callback):
		confirmation_state.confirmation_committed.connect(callback)


# 正式确认只写入本周目该关的首条经文；后续重复提交保留原记录。
func write_confirmed_oracle(level_profile: LevelProfile, candidate: Dictionary) -> bool:
	if level_profile == null or _find_entry(StringName(level_profile.level_id)) != null:
		return false
	var entry: ScriptureEntry = _build_entry(level_profile, candidate)
	if entry == null:
		return false
	if VERSE_CONFIG.minimum_verse_number <= 0 or VERSE_CONFIG.maximum_verse_number < VERSE_CONFIG.minimum_verse_number:
		return false
	# 只在首条正式写入时抽取一次，读档和读取继续使用经文已保存的节号。
	entry.verse_number = randi_range(VERSE_CONFIG.minimum_verse_number, VERSE_CONFIG.maximum_verse_number)
	entries.append(entry)
	emit_changed()
	return true


# 返回经文快照，读取方修改返回资源时不会改写圣典原记录。
func get_entry_for_level(level_id: StringName) -> ScriptureEntry:
	var entry: ScriptureEntry = _find_entry(level_id)
	return entry.duplicate(true) as ScriptureEntry if entry != null else null


# 按首次写入时保存的原章号返回经文快照，读取时不重排内部保存列表。
func get_ordered_entries() -> Array[ScriptureEntry]:
	var ordered_entries: Array[ScriptureEntry] = []
	for entry: ScriptureEntry in entries:
		if entry != null:
			ordered_entries.append(entry.duplicate(true) as ScriptureEntry)
	ordered_entries.sort_custom(_entry_precedes)
	return ordered_entries


# 为目录中的每关保留一个章节位置；无正式经文时 entry 为 null，章号保持原值。
func get_chapter_slots(level_catalog: LevelCatalog) -> Array[Dictionary]:
	var chapter_slots: Array[Dictionary] = []
	if level_catalog == null:
		return chapter_slots
	for level_profile: LevelProfile in level_catalog.profiles:
		if level_profile == null:
			continue
		var entry: ScriptureEntry = get_entry_for_level(StringName(level_profile.level_id))
		chapter_slots.append({
			"level_id": StringName(level_profile.level_id),
			"chapter_number": entry.chapter_number if entry != null else level_profile.level_order,
			"entry": entry,
		})
	chapter_slots.sort_custom(_chapter_precedes)
	return chapter_slots


# 原章号相同时按稳定关卡 ID 排列，保证读取结果顺序一致。
func _entry_precedes(first: ScriptureEntry, second: ScriptureEntry) -> bool:
	if first.chapter_number != second.chapter_number:
		return first.chapter_number < second.chapter_number
	return str(first.level_id) < str(second.level_id)


# 章节位置与经文采用相同的原序号规则，缺章参与排列且不压缩编号。
func _chapter_precedes(first: Dictionary, second: Dictionary) -> bool:
	if int(first["chapter_number"]) != int(second["chapter_number"]):
		return int(first["chapter_number"]) < int(second["chapter_number"])
	return str(first["level_id"]) < str(second["level_id"])


# 接收方只处理绑定到自身的当前周目，并按关卡 ID 解析真实来源配置。
func _on_confirmation_committed(run_data: SaveData, level_id: String, candidate: Dictionary, level_catalog: LevelCatalog) -> void:
	if run_data == null or run_data.scripture_data != self:
		return
	for level_profile: LevelProfile in level_catalog.profiles:
		if level_profile != null and level_profile.level_id == level_id:
			write_confirmed_oracle(level_profile, candidate)
			return


# 确认候选只有原句 ID 和倾向；文本、主播名和章号从对应关卡复制为快照。
func _build_entry(level_profile: LevelProfile, candidate: Dictionary) -> ScriptureEntry:
	var original_line_id: StringName = StringName(str(candidate.get("original_sentence_id", "")))
	var tendency_id: String = str(candidate.get("tendency", ""))
	if level_profile.level_id.is_empty() or level_profile.level_order <= 0 or original_line_id.is_empty():
		return null
	if not ["orthodox", "heretical", "absurd"].has(tendency_id):
		return null
	for speech: LevelSpeech in level_profile.normal_speech_pool:
		if speech == null or StringName(speech.original_sentence_id) != original_line_id:
			continue
		var entry: ScriptureEntry = ScriptureEntry.new()
		entry.level_id = StringName(level_profile.level_id)
		entry.streamer_name = level_profile.streamer_name
		entry.original_line_id = original_line_id
		entry.original_line_text = speech.text
		entry.tendency_id = tendency_id
		entry.chapter_number = level_profile.level_order
		return entry
	return null


# 去重直接查询已保存记录，重建确认状态或读档后仍采用同一关卡身份。
func _find_entry(level_id: StringName) -> ScriptureEntry:
	for entry: ScriptureEntry in entries:
		if entry != null and entry.level_id == level_id:
			return entry
	return null
