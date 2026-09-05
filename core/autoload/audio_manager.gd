extends Node

const SFX_PLAYER_COUNT: int = 8
const UI_PLAYER_COUNT: int = 4

const MUSIC_BUS_NAME: StringName = &"Music"
const SFX_BUS_NAME: StringName = &"SFX"
const UI_BUS_NAME: StringName = &"UI"

var _music_player: AudioStreamPlayer
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
	if _music_player.stream == stream and _music_player.is_playing():
		return

	_music_player.bus = MUSIC_BUS_NAME
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	# 停止音乐并清除 Stream，让下一次播放从头开始。
	if not is_instance_valid(_music_player):
		return

	_music_player.stop()
	_music_player.stream = null


func play_sfx(stream: AudioStream) -> void:
	# 将非空间 SFX 播放到固定的 SFX 播放器池。
	_play_from_pool(stream, _sfx_players, _sfx_play_order, SFX_BUS_NAME, "play_sfx")


func play_ui(stream: AudioStream) -> void:
	# 将 UI 音效播放到独立的 UI 播放器池。
	_play_from_pool(stream, _ui_players, _ui_play_order, UI_BUS_NAME, "play_ui")


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
