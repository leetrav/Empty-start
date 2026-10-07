extends SceneTree


# 本卡只运行未提交撤回这一项规则，用公开接收 / 读取入口核对数据边界。
func _initialize() -> void:
	seed(1505)
	if not _test_restart_discards_only_current_pending_entry():
		quit(1)
		return
	print("PASS SC-05: 重开撤回本关暂存并保留已提交经文，共 1 项")
	quit(0)


# 错关撤回不会清当前暂存；正确撤回保持此前正式原文和节号。
func _test_restart_discards_only_current_pending_entry() -> bool:
	var run_data: SaveData = SaveData.new()
	var previous_level: LevelProfile = _make_level("previous_level", 1)
	var current_level: LevelProfile = _make_level("current_level", 2)
	run_data.scripture_data.write_confirmed_oracle(previous_level, _candidate(previous_level))
	var previous_entry: ScriptureEntry = run_data.scripture_data.get_entry_for_level(&"previous_level")
	if not run_data.scripture_data.stage_oracle(current_level, _candidate(current_level)):
		push_error("SC-05 未提交经文没有进入本场暂存")
		return false
	if run_data.scripture_data.rollback_uncommitted(&"previous_level") or run_data.scripture_data.get_pending_entry_for_level(&"current_level") == null:
		push_error("SC-05 撤回其他关时清除了当前暂存")
		return false
	if not run_data.scripture_data.rollback_uncommitted(&"current_level"):
		push_error("SC-05 当前关暂存没有被撤回")
		return false
	var kept_entry: ScriptureEntry = run_data.scripture_data.get_entry_for_level(&"previous_level")
	if run_data.scripture_data.get_pending_entry_for_level(&"current_level") != null or run_data.scripture_data.get_entry_for_level(&"current_level") != null or run_data.scripture_data.entries.size() != 1:
		push_error("SC-05 暂存撤回范围错误")
		return false
	if kept_entry == null or kept_entry.original_line_text != previous_entry.original_line_text or kept_entry.verse_number != previous_entry.verse_number:
		push_error("SC-05 重开改变了此前已提交经文")
		return false
	return true


# 本场和历史关卡都用合法来源 Resource，测试不读取模块私有状态。
func _make_level(level_id: String, chapter_number: int) -> LevelProfile:
	var level: LevelProfile = LevelProfile.new()
	level.level_id = level_id
	level.level_order = chapter_number
	var speech: LevelSpeech = LevelSpeech.new()
	speech.original_sentence_id = level_id + "_line"
	speech.text = "测试经文 " + level_id
	speech.tendency_id = "orthodox"
	level.normal_speech_pool.append(speech)
	return level


# 确认输入沿用真实生产字段。
func _candidate(level: LevelProfile) -> Dictionary:
	var speech: LevelSpeech = level.normal_speech_pool[0]
	return {"original_sentence_id": speech.original_sentence_id, "tendency": speech.tendency_id}
