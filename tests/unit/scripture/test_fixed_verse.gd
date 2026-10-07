extends SceneTree

const LEVEL_PROFILE: LevelProfile = preload("res://data/level_configuration/level_001.tres")
const VERSE_CONFIG: ScriptureVerseConfig = preload("res://data/scripture/verse_number_config.tres")


# 固定随机种子，仅运行本卡首次生成和后续固定两项规则。
func _initialize() -> void:
	seed(1503)
	if not _test_first_write_generates_verse() or not _test_reads_keep_first_verse():
		quit(1)
		return
	print("PASS SC-03: 首次生成 1～99 节号、后续固定，共 2 项")
	quit(0)


# 首次正式写入产生配置范围内的整数编号。
func _test_first_write_generates_verse() -> bool:
	if VERSE_CONFIG.minimum_verse_number != 1 or VERSE_CONFIG.maximum_verse_number != 99:
		push_error("SC-03 集中配置没有保持 1～99 范围")
		return false
	var data: ScriptureData = ScriptureData.new()
	if not data.write_confirmed_oracle(LEVEL_PROFILE, _candidate()):
		push_error("SC-03 首次写入失败")
		return false
	var entry: ScriptureEntry = data.get_entry_for_level(StringName(LEVEL_PROFILE.level_id))
	if entry.verse_number < 1 or entry.verse_number > 99:
		push_error("SC-03 首次节号超出 1～99")
		return false
	return true


# 读取快照或重复提交都不会再次抽号或改写首次节号。
func _test_reads_keep_first_verse() -> bool:
	var data: ScriptureData = ScriptureData.new()
	data.write_confirmed_oracle(LEVEL_PROFILE, _candidate())
	var level_id: StringName = StringName(LEVEL_PROFILE.level_id)
	var first_verse: int = data.get_entry_for_level(level_id).verse_number
	var viewed_entry: ScriptureEntry = data.get_entry_for_level(level_id)
	viewed_entry.verse_number = 0
	data.write_confirmed_oracle(LEVEL_PROFILE, _candidate())
	if data.get_entry_for_level(level_id).verse_number != first_verse or data.entries.size() != 1:
		push_error("SC-03 读取或重复提交改写了首次节号")
		return false
	return true


# 用真实关卡中的第一句作为确认候选，配置资源在测试期间只读。
func _candidate() -> Dictionary:
	var speech: LevelSpeech = LEVEL_PROFILE.normal_speech_pool[0]
	return {"original_sentence_id": speech.original_sentence_id, "tendency": speech.tendency_id}
