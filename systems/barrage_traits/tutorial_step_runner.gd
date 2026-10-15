class_name TutorialStepRunner
extends RefCounted

signal hint_requested(step_id: String, hint_text: String)
signal step_completed(step_id: String)
signal tutorial_completed(config_id: String)

const TABLE_PATH := "res://data/source_tables/24_新手教学配置.csv"
var _config_id: String = ""
var _steps: Array[Dictionary] = []
var _active_index: int = -1
var _active_triggered: bool = false


## 按教学配置 ID 加载启用步骤；完成进度由本周目拥有者保存并传入。
func begin(config_id: String, completed_step_ids: Array[String] = []) -> bool:
	_config_id = config_id
	_steps.clear()
	_active_index = -1
	_active_triggered = false
	var rows := _read_rows()
	for row: Dictionary in rows:
		if row.get("tutorial_config_id", "") != config_id or row.get("enabled", "").to_lower() != "true":
			continue
		_steps.append(row)
	_steps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("step_order", "0")) < int(b.get("step_order", "0"))
	)
	for step: Dictionary in _steps:
		if not completed_step_ids.has(String(step.get("step_id", ""))):
			_active_index = _steps.find(step)
			return true
	if not _steps.is_empty():
		tutorial_completed.emit(_config_id)
	return false


## 只有当前步骤配置的真实事件可推进教学，后续步骤事件不会越级。
func notify_event(event_id: String) -> bool:
	if _active_index < 0 or _active_index >= _steps.size():
		return false
	var step: Dictionary = _steps[_active_index]
	if _active_triggered and event_id == str(step.get("completion_event", "")):
		step_completed.emit(str(step.get("step_id", "")))
		_active_index += 1
		if _active_index >= _steps.size():
			tutorial_completed.emit(_config_id)
			return true
		step = _steps[_active_index]
		_active_triggered = false
		if event_id == str(step.get("trigger_event", "")):
			_active_triggered = true
			hint_requested.emit(str(step.get("step_id", "")), str(step.get("hint_text", "")))
		return true
	if not _active_triggered and event_id == str(step.get("trigger_event", "")):
		_active_triggered = true
		hint_requested.emit(str(step.get("step_id", "")), str(step.get("hint_text", "")))
		return true
	return false


func get_active_step_id() -> String:
	if _active_index < 0 or _active_index >= _steps.size():
		return ""
	return str(_steps[_active_index].get("step_id", ""))


func _read_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(TABLE_PATH, FileAccess.READ)
	if file == null:
		push_error("TutorialStepRunner: 无法读取正式教学表。")
		return rows
	var headers: PackedStringArray = file.get_csv_line()
	while not file.eof_reached():
		var values: PackedStringArray = file.get_csv_line()
		if values.size() != headers.size():
			continue
		var row: Dictionary = {}
		for index: int in headers.size():
			row[headers[index]] = values[index]
		rows.append(row)
	return rows
