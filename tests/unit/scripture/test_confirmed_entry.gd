extends SceneTree


# 只运行本卡的首次写入与同关去重两个规则用例。
func _initialize() -> void:
	if not _test_first_confirmation_writes_entry() or not _test_same_level_keeps_first_entry():
		quit(1)
		return
	print("PASS SC-02: 首次确认写入、同周目同关去重，共 2 项")
	quit(0)


# 真实确认信号把关卡和原句快照写进当前 SaveData 的圣典。
func _test_first_confirmation_writes_entry() -> bool:
	var run_data: SaveData = SaveData.new()
	var catalog: LevelCatalog = _make_catalog()
	var confirmation_state: FinalOracleConfirmationState = FinalOracleConfirmationState.new(run_data)
	run_data.scripture_data.bind_confirmation_state(confirmation_state, catalog)
	confirmation_state.confirm_selection("scripture_level", {"original_sentence_id": "scripture_line", "tendency": "orthodox"})
	var entry: ScriptureEntry = run_data.scripture_data.get_entry_for_level(&"scripture_level")
	if entry == null or run_data.scripture_data.entries.size() != 1:
		push_error("SC-02 首次神谕确认没有写入经文")
		return false
	if entry.streamer_name != "测试主播" or entry.chapter_number != 3 or entry.original_line_text != "测试原句" or entry.tendency_id != "orthodox":
		push_error("SC-02 经文没有保留真实关卡与原句信息")
		return false
	return true


# 再建确认状态也不能绕过存档中的同关记录，首次原句保持固定。
func _test_same_level_keeps_first_entry() -> bool:
	var run_data: SaveData = SaveData.new()
	var catalog: LevelCatalog = _make_catalog()
	var first_state: FinalOracleConfirmationState = FinalOracleConfirmationState.new(run_data)
	run_data.scripture_data.bind_confirmation_state(first_state, catalog)
	first_state.confirm_selection("scripture_level", {"original_sentence_id": "scripture_line", "tendency": "orthodox"})
	var second_state: FinalOracleConfirmationState = FinalOracleConfirmationState.new(run_data)
	run_data.scripture_data.bind_confirmation_state(second_state, catalog)
	second_state.confirm_selection("scripture_level", {"original_sentence_id": "scripture_other_line", "tendency": "absurd"})
	var entry: ScriptureEntry = run_data.scripture_data.get_entry_for_level(&"scripture_level")
	if run_data.scripture_data.entries.size() != 1 or entry == null or entry.original_line_id != &"scripture_line":
		push_error("SC-02 同关再次提交新增或覆盖了首次经文")
		return false
	return true


# 构造与真实候选字段一致的最小关卡来源。
func _make_catalog() -> LevelCatalog:
	var level_profile: LevelProfile = LevelProfile.new()
	level_profile.level_id = "scripture_level"
	level_profile.level_order = 3
	level_profile.streamer_name = "测试主播"
	var speech: LevelSpeech = LevelSpeech.new()
	speech.original_sentence_id = "scripture_line"
	speech.text = "测试原句"
	var other_speech: LevelSpeech = LevelSpeech.new()
	other_speech.original_sentence_id = "scripture_other_line"
	other_speech.text = "测试另一原句"
	level_profile.normal_speech_pool.assign([speech, other_speech])
	var catalog: LevelCatalog = LevelCatalog.new()
	catalog.profiles.append(level_profile)
	return catalog
