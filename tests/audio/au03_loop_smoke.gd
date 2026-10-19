extends Node

## 测试同时解码四Boss所有采用的循环，每份真实经过三次循环；不替代人耳接缝验收。
var _players: Array[AudioStreamPlayer] = []
var _wraps: Array[int] = []
var _positions: Array[float] = []


func _ready() -> void:
	var rows: String = FileAccess.get_file_as_string("res://data/source_tables/17_音频事件.csv")
	for line: String in rows.split("\n"):
		if not line.begins_with("music_") or not line.contains(",music,assets/audio/music/"):
			continue
		var stream: AudioStreamOggVorbis = load("res://" + line.get_slice(",", 2))
		assert(stream.loop and stream.get_length() > 1.0)
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = -100.0
		add_child(player)
		_players.append(player)
		_wraps.append(0)
		_positions.append(0.0)
		player.play()
	# 等真实音频回绕，避免无声/硬件驱动与场景计时的微小偏差造成误报。
	var deadline: int = Time.get_ticks_msec() + 100000
	while _wraps.min() < 3 and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1).timeout
	var passed: bool = _players.size() == 17 and _wraps.min() >= 3
	print("AU03_LOOPS_PASS " + str(_wraps) if passed else "AU03_LOOPS_FAIL " + str(_wraps))
	for player: AudioStreamPlayer in _players:
		player.stop()
		player.stream = null
		player.queue_free()
	_players.clear()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if passed else 1)


func _process(_delta: float) -> void:
	for index: int in range(_players.size()):
		var pos: float = _players[index].get_playback_position()
		if pos + 1.0 < _positions[index]:
			_wraps[index] += 1
		_positions[index] = pos
