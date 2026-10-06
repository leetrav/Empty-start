class_name FinalOracleSelectionTimer
extends RefCounted

signal remaining_time_changed(seconds_remaining: float)
signal expired

const CHOICE_DURATION_SECONDS: float = 10.0

var _remaining_seconds: float = 0.0
var _is_running: bool = false


# 候选开放时由流程方启动完整的十秒选择窗口。
func start() -> void:
	_remaining_seconds = CHOICE_DURATION_SECONDS
	_is_running = true
	remaining_time_changed.emit(_remaining_seconds)


# 全局暂停时不推进时间；到期只发出一次事实信号。
func advance(delta_seconds: float, is_globally_paused: bool) -> void:
	if not _is_running or is_globally_paused:
		return
	_remaining_seconds = maxf(0.0, _remaining_seconds - delta_seconds)
	remaining_time_changed.emit(_remaining_seconds)
	if _remaining_seconds <= 0.0:
		_is_running = false
		expired.emit()


func get_remaining_seconds() -> float:
	return _remaining_seconds


func is_running() -> bool:
	return _is_running
