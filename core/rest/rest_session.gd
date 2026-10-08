class_name RestSession
extends RefCounted

signal opened(result_snapshot: Dictionary)

var _result_snapshot: Dictionary = {}
var _open: bool = false


# 休息入口只冻结本场已经确定的结果；重复打开不替换第一次收到的事实。
func open_result(result_snapshot: Dictionary) -> bool:
	if _open or String(result_snapshot.get("level_id", "")).is_empty():
		return false
	var result_kind: String = String(result_snapshot.get("result_kind", ""))
	if result_kind != "pk_win_unbroken" and result_kind != "breakthrough_oracle_complete":
		return false
	_result_snapshot = result_snapshot.duplicate(true)
	_open = true
	opened.emit(get_result_snapshot())
	return true


func is_open() -> bool:
	return _open


func get_result_snapshot() -> Dictionary:
	return _result_snapshot.duplicate(true)


# 只读取当前成功关卡已提交的成果，不调用圣典、卡片或吞并的发放入口。
func read_committed_rewards(
		run_data: SaveData,
		level_catalog: LevelCatalog,
		loser_card_catalog: LoserCardCatalog
	) -> Dictionary:
	var rewards: Dictionary = {
		"new_scripture_entry": null,
		"new_loser_card": null,
		"new_assimilation": {},
	}
	if not _open or run_data == null:
		return rewards
	if String(_result_snapshot.get("result_kind", "")) != "breakthrough_oracle_complete":
		return rewards

	var level_id := StringName(str(_result_snapshot.get("level_id", "")))
	if level_id.is_empty():
		return rewards
	if run_data.scripture_data != null:
		rewards["new_scripture_entry"] = run_data.scripture_data.get_entry_for_level(level_id)

	# 败者卡的来源与本场新增判断归 16，缺少关卡目录也可以独立读取。
	if run_data.loser_card_data != null:
		var new_card: Dictionary = run_data.loser_card_data.get_new_card_for_level(level_id, loser_card_catalog)
		if not new_card.is_empty():
			rewards["new_loser_card"] = new_card

	if level_catalog == null:
		return rewards
	var session_level: LevelProfile
	for profile: LevelProfile in level_catalog.profiles:
		if profile != null and StringName(profile.level_id) == level_id:
			session_level = profile
			break
	if session_level == null or session_level.streamer_id.is_empty():
		return rewards
	var streamer_id := StringName(session_level.streamer_id)

	# 来源和新增条目归 14 持有，Rest 只按真实关卡 / 主播读取已提交快照。
	if run_data.assimilation_data != null:
		rewards["new_assimilation"] = run_data.assimilation_data.get_new_content_for_source(level_id, streamer_id)

	return rewards
