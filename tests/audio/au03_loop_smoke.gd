extends Node

## 测试同时解码三份循环，每份真实经过三次循环；不替代人耳接缝验收。
var _players: Array[AudioStreamPlayer] = []
var _wraps: Array[int] = [0, 0, 0, 0]
var _positions: Array[float] = [0.0, 0.0, 0.0, 0.0]


func _ready() -> void:
	for group: String in ["intro", "low", "mid", "high"]:
		var stream: AudioStreamOggVorbis = load("res://assets/audio/music/fermi/teek_" + group + ".ogg")
		assert(stream.loop and absf(stream.get_length() - 19.2) < 0.002)
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = -80.0
		add_child(player)
		_players.append(player)
		player.play()
	# 等真实音频回绕，避免无声/硬件驱动与场景计时的微小偏差造成误报。
	var deadline: int = Time.get_ticks_msec() + 75000
	while _wraps.min() < 3 and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1).timeout
	var passed: bool = _wraps[0] >= 3 and _wraps[1] >= 3 and _wraps[2] >= 3 and _wraps[3] >= 3
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
