class_name EndingMusicPresenter
extends Node

## 神降临和结局页面各自持有，不新增播放器；跨场景只交接音乐所有权。
const EVENT: StringName = &"music_ending_tendoh"
var _started: bool = false
var _handoff: bool = false


# 神谕先按原时长停留并退字，完成事实到来后才淡入结尾曲；重复通知不重播。
func on_divine_phase(phase: StringName, _prompt: String, progress: float) -> void:
	if phase == &"completed" and progress >= 1.0:
		start()


# 结局页接管已起播的同曲时不重置进度或淡入；读档直达则从头淡入。
func start() -> void:
	if _started:
		return
	_started = true
	if AudioManager.get_music_event_id() == EVENT:
		return
	AudioManager.set_music_paused(false)
	AudioManager.restore_music()
	AudioManager.change_music(EVENT, 0.8, 0.0, 2.5, false)


func set_paused(paused: bool) -> void:
	if _started and AudioManager.get_music_event_id() == EVENT:
		AudioManager.set_music_paused(paused)


# change_scene会立即移除旧场景，所以必须在路由前标记；失败时撤销。
func set_handoff(enabled: bool) -> void:
	_handoff = enabled


func _exit_tree() -> void:
	if _started and not _handoff and AudioManager.get_music_event_id() == EVENT:
		AudioManager.set_music_paused(false)
		AudioManager.fade_out_music()
