class_name RoomMusicPresenter
extends Node

## 房间页面持有的音乐消费者，共用AudioManager；不创建播放器或写存档。
const EVENT: StringName = &"music_rest_room"
# 原曲约2.4秒才起声；从首个音符前50ms播放，跳过空白并保留音头。
const ENTRY_SECONDS: float = 2.35
const AFTER_PK_EVENT: StringName = &"music_rest_after_pk"
var _event: StringName = EVENT
var _active: bool = false


# 同一结果重复展示、历史页往返不重播；同曲房间交接沿用播放位置。
# 首播前用Pure Soul，战后与后续开播房间用夢灯；同曲交接不重置位置。
func start(after_pk: bool = false) -> void:
	var requested: StringName = AFTER_PK_EVENT if after_pk else EVENT
	if _active and _event == requested and AudioManager.get_music_event_id() == requested:
		return
	_event = requested
	_active = true
	AudioManager.set_music_paused(false)
	AudioManager.restore_music()
	AudioManager.change_music(_event, 0.6, 0.0 if after_pk else ENTRY_SECONDS, 0.6, false)


# 只淡出自己仍持有的音乐，旧页面离开不能停止已接管的Boss或漫画音乐。
func stop() -> void:
	if _active and AudioManager.get_music_event_id() == _event:
		AudioManager.set_music_paused(false)
		AudioManager.fade_out_music()
	_active = false


func set_paused(paused: bool) -> void:
	if _active and AudioManager.get_music_event_id() == _event:
		AudioManager.set_music_paused(paused)


func _exit_tree() -> void:
	stop()
