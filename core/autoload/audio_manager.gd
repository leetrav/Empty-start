extends Node

# 击破静音请求完成后通知调用方；中途被新音乐请求替代时不发送。
signal music_silenced

const SFX_PLAYER_COUNT: int = 8
const UI_PLAYER_COUNT: int = 4

const MUSIC_BUS_NAME: StringName = &"Music"
const SFX_BUS_NAME: StringName = &"SFX"
const UI_BUS_NAME: StringName = &"UI"
const AUDIO_EVENT_CONFIG: AudioEventConfig = preload("res://data/shared/audio_event_config.tres")

# 通过同一 Resource 引用读取字段，避免 const Resource 属性在解析期折叠为旧值。
var _audio_config: AudioEventConfig = AUDIO_EVENT_CONFIG
var _music_player: AudioStreamPlayer
var _outgoing_music_player: AudioStreamPlayer
var _music_tween: Tween
var _duck_tween: Tween
# 两首音乐的淡变与共同压低分别保存增益，避免 Tween 同时争用播放器音量。
var _music_gain: float = 0.0:
	set(value):
		_music_gain = clampf(value, 0.0, 1.0)
		_apply_music_gains()
var _outgoing_gain: float = 0.0:
	set(value):
		_outgoing_gain = clampf(value, 0.0, 1.0)
		_apply_music_gains()
var _duck_gain: float = 1.0:
	set(value):
		_duck_gain = clampf(value, 0.0, 1.0)
		_apply_music_gains()
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _sfx_play_order: Array[int] = []
var _ui_play_order: Array[int] = []
var _play_sequence: int = 0


func _ready() -> void:
	# 初始化固定播放器池，并在绑定 Bus 前检查项目总线布局。
	var music_bus_available: bool = _ensure_audio_bus(MUSIC_BUS_NAME)
	var sfx_bus_available: bool = _ensure_audio_bus(SFX_BUS_NAME)
	var ui_bus_available: bool = _ensure_audio_bus(UI_BUS_NAME)

	_music_player = _create_player("MusicPlayer", MUSIC_BUS_NAME, music_bus_available)
	_outgoing_music_player = _create_player("MusicTransitionPlayer", MUSIC_BUS_NAME, music_bus_available)
	_apply_music_gains()

	for index in range(SFX_PLAYER_COUNT):
		_sfx_players.append(_create_player("SFXPlayer_%d" % (index + 1), SFX_BUS_NAME, sfx_bus_available))
		_sfx_play_order.append(-1)

	for index in range(UI_PLAYER_COUNT):
		_ui_players.append(_create_player("UIPlayer_%d" % (index + 1), UI_BUS_NAME, ui_bus_available))
		_ui_play_order.append(-1)


func play_music(stream: AudioStream) -> void:
	# 播放 Music Bus 上的音乐；重复传入当前音乐时保持播放位置。
	if stream == null:
		push_warning("AudioManager: play_music() received an empty AudioStream.")
		return
	if not _ensure_audio_bus(MUSIC_BUS_NAME):
		return
	if not is_instance_valid(_music_player):
		push_error("AudioManager: music player is not initialized.")
		return
	# 原有直接播放入口保持立即播放，也可取消尚未完成的淡出。
	_cancel_music_tween()
	_stop_outgoing_music()
	_music_gain = 1.0
	_music_player.bus = MUSIC_BUS_NAME
	if _music_player.stream == stream and _music_player.is_playing():
		return
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	# 显式停止取消全部音乐过渡并清空两播放器，让下一次播放从头开始。
	_cancel_music_tween()
	if _duck_tween != null:
		_duck_tween.kill()
		_duck_tween = null
	_stop_outgoing_music()
	_music_gain = 0.0
	_duck_gain = 1.0
	if not is_instance_valid(_music_player):
		return

	_music_player.stop()
	_music_player.stream = null


# 按 AU-01 音乐事件请求主音乐；首次淡入，换曲时交叉切换。
func change_music(event_id: StringName) -> bool:
	var event: AudioEvent = _audio_config.find_event(event_id)
	if event == null or event.audio_type != AudioEvent.AudioType.MUSIC or event.stream == null:
		push_warning("AudioManager: music event '%s' is missing, empty or not Music." % str(event_id))
		return false
	if not _ensure_audio_bus(MUSIC_BUS_NAME) or not is_instance_valid(_music_player):
		return false
	_cancel_music_tween()
	if _music_player.stream != event.stream or not _music_player.is_playing():
		# 过渡中第三首到来时回收旧淡出尾音，始终只使用两播放器。
		_stop_outgoing_music()
		var previous_player: AudioStreamPlayer = _music_player
		_music_player = _outgoing_music_player
		_outgoing_music_player = previous_player
		_outgoing_gain = _music_gain
		_music_gain = 0.0
		_music_player.bus = MUSIC_BUS_NAME
		_music_player.stream = event.stream
		_music_player.play()
	var has_outgoing_music: bool = _outgoing_music_player.stream != null and _outgoing_music_player.is_playing()
	var duration: float = _audio_config.music_cross_fade_seconds if has_outgoing_music else _audio_config.music_fade_in_seconds
	_tween_music_gains(1.0, duration, _finish_music_change)
	return true


# 使用配置时长淡出并停止，适用于离开当前音乐阶段。
func fade_out_music() -> void:
	_tween_music_gains(0.0, _audio_config.music_fade_out_seconds, _finish_music_stop.bind(false))


# 击破流程淡出至静音并停止；完成后保持静音，等待调用方请求下一首。
func fade_to_silence() -> void:
	_tween_music_gains(0.0, _audio_config.music_silence_seconds, _finish_music_stop.bind(true))


# 临时压低所有参与切换的音乐；重复调用始终取同一倍率，不叠加。
func duck_music() -> void:
	_tween_duck_gain(_audio_config.music_duck_volume, _audio_config.music_duck_seconds)


# 仅恢复音乐压低倍率，保持当前播放位置和玩家 Music Bus 设置。
func restore_music() -> void:
	_tween_duck_gain(1.0, _audio_config.music_restore_seconds)


# 只控制播放器增益；Music Bus 的玩家音量和静音仍由 SettingsManager 管理。
func _apply_music_gains() -> void:
	if is_instance_valid(_music_player):
		_music_player.volume_linear = _music_gain * _duck_gain
	if is_instance_valid(_outgoing_music_player):
		_outgoing_music_player.volume_linear = _outgoing_gain * _duck_gain


# 新请求取消旧 Tween 及其回调，避免旧淡出结束后停止新音乐。
func _cancel_music_tween() -> void:
	if _music_tween != null:
		_music_tween.kill()
		_music_tween = null


# 两播放器并行淡变，完成回调在淡变结束后执行；零时长直接完成。
func _tween_music_gains(target_gain: float, duration: float, completion: Callable) -> void:
	_cancel_music_tween()
	if duration <= 0.0:
		_music_gain = target_gain
		_outgoing_gain = 0.0
		completion.call()
		return
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(self, "_music_gain", target_gain, duration)
	_music_tween.tween_property(self, "_outgoing_gain", 0.0, duration)
	_music_tween.chain().tween_callback(completion)


# 压低 Tween 与换曲 Tween 分开，交叉切换时两首共同压低。
func _tween_duck_gain(target_gain: float, duration: float) -> void:
	if _duck_tween != null:
		_duck_tween.kill()
	if duration <= 0.0:
		_duck_tween = null
		_duck_gain = target_gain
		return
	_duck_tween = create_tween()
	_duck_tween.tween_property(self, "_duck_gain", clampf(target_gain, 0.0, 1.0), duration)


# 换曲完成只清理旧曲，当前主音乐继续播放。
func _finish_music_change() -> void:
	_music_tween = null
	_stop_outgoing_music()


# 在实际停止后发送击破静音完成事实，调用方可等待此信号推进表现。
func _finish_music_stop(notify_silence: bool) -> void:
	_music_tween = null
	stop_music()
	if notify_silence:
		music_silenced.emit()


# 清理交叉切换使用的旧播放器，不影响当前曲目。
func _stop_outgoing_music() -> void:
	if is_instance_valid(_outgoing_music_player):
		_outgoing_music_player.stop()
		_outgoing_music_player.stream = null
	_outgoing_gain = 0.0


func play_sfx(stream: AudioStream) -> void:
	# 将非空间 SFX 播放到固定的 SFX 播放器池。
	_play_from_pool(stream, _sfx_players, _sfx_play_order, SFX_BUS_NAME, "play_sfx")


func play_ui(stream: AudioStream) -> void:
	# 将 UI 音效播放到独立的 UI 播放器池。
	_play_from_pool(stream, _ui_players, _ui_play_order, UI_BUS_NAME, "play_ui")


# 按稳定事件 ID 查配置，再交给现有播放器和 Bus 入口执行。
func play_event(event_id: StringName) -> void:
	var event: AudioEvent = _audio_config.find_event(event_id)
	if event == null:
		push_warning("AudioManager: audio event '%s' is not configured." % str(event_id))
		return
	if event.stream == null:
		push_warning("AudioManager: audio event '%s' has no AudioStream." % str(event_id))
		return

	match event.audio_type:
		AudioEvent.AudioType.MUSIC:
			change_music(event_id)
		AudioEvent.AudioType.SFX:
			play_sfx(event.stream)
		AudioEvent.AudioType.UI:
			play_ui(event.stream)
		_:
			push_error("AudioManager: audio event '%s' has an unsupported audio type." % str(event_id))


func _create_player(player_name: String, bus_name: StringName, bus_available: bool) -> AudioStreamPlayer:
	# 创建单个播放器；Bus 缺失时保留空播放器，避免静默回落到 Master。
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	if bus_available:
		player.bus = bus_name
	add_child(player)
	return player


func _play_from_pool(
		stream: AudioStream,
		players: Array[AudioStreamPlayer],
		play_order: Array[int],
		bus_name: StringName,
		method_name: String
	) -> void:
	# 查找空闲播放器；池满时按最早开始播放的顺序复用。
	if stream == null:
		push_warning("AudioManager: %s() received an empty AudioStream." % method_name)
		return
	if not _ensure_audio_bus(bus_name):
		return

	var player_index: int = _find_pool_player_index(players, play_order)
	if player_index < 0:
		push_error("AudioManager: %s() has no available player." % method_name)
		return

	var player: AudioStreamPlayer = players[player_index]
	player.bus = bus_name
	player.stop()
	player.stream = stream
	player.play()
	play_order[player_index] = _play_sequence
	_play_sequence += 1


func _find_pool_player_index(players: Array[AudioStreamPlayer], play_order: Array[int]) -> int:
	# 空闲播放器按池内顺序优先返回，全部占用时返回最早播放者。
	for index in range(players.size()):
		if not players[index].is_playing():
			return index

	if players.is_empty():
		return -1

	var oldest_index: int = 0
	for index in range(1, players.size()):
		if play_order[index] < play_order[oldest_index]:
			oldest_index = index
	return oldest_index


func _ensure_audio_bus(bus_name: StringName) -> bool:
	# 每次使用前确认目标 Bus 存在，避免 Godot 自动回落到 Master。
	if AudioServer.get_bus_index(bus_name) >= 0:
		return true

	push_error("AudioManager: required Audio Bus '%s' was not found." % str(bus_name))
	return false
