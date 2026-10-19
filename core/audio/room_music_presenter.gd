class_name RoomMusicPresenter
extends Node

## 房间页面持有的音乐消费者，共用AudioManager；不创建播放器或写存档。
const EVENT: StringName = &"music_rest_room"
var _active: bool = false


# 同一结果重复展示、历史页往返不重播；同曲房间交接沿用播放位置。
func start() -> void:
	if _active and AudioManager.get_music_event_id() == EVENT:
		return
	_active = true
	AudioManager.set_music_paused(false)
	AudioManager.restore_music()
	AudioManager.change_music(EVENT, 0.8, 0.0, 1.5, false)


# 只淡出自己仍持有的音乐，旧页面离开不能停止已接管的Boss或漫画音乐。
func stop() -> void:
	if _active and AudioManager.get_music_event_id() == EVENT:
		AudioManager.set_music_paused(false)
		AudioManager.fade_out_music()
	_active = false


func set_paused(paused: bool) -> void:
	if _active and AudioManager.get_music_event_id() == EVENT:
		AudioManager.set_music_paused(paused)


func _exit_tree() -> void:
	stop()
