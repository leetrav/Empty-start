class_name EndingSequenceView
extends Control

signal sequence_finished(reason: StringName)

const CANVAS_SIZE := Vector2(1920, 1080)
var _sequence: ComicSequence
var _player: ComicPanelPlaybackControl
var _tween: Tween
var _paused: bool = false
@onready var _canvas: Control = %Canvas
@onready var _caption: Label = %Caption


## 独立结束序列只呈现注入资源；A决定完成后路由，不读取开场P5/P6。
func _ready() -> void:
	resized.connect(_fit_canvas)
	_fit_canvas()


## 空序列明确拒绝；原图位置必须完整，避免把空配置当作已交付演出。
func play_sequence(sequence: ComicSequence) -> bool:
	if not is_node_ready() or sequence == null or sequence.frames.is_empty():
		return false
	for frame: ComicFrame in sequence.frames:
		if frame == null or frame.textures.is_empty() or frame.positions.size() != frame.textures.size():
			return false
		for texture: Texture2D in frame.textures:
			if texture == null:
				return false
	stop()
	_sequence = sequence
	_paused = false
	_player = ComicPanelPlaybackControl.new()
	_player.panel_count = sequence.frames.size()
	_player.auto_complete_last_panel = true
	for frame: ComicFrame in sequence.frames:
		_player.panel_intervals_seconds.append(frame.seconds)
	_player.panel_display_requested.connect(_show_frame)
	_player.playback_completed.connect(_on_completed)
	add_child(_player)
	return _player.start_playback()


## 点击推进复用已有漫画控制器；暂停时不快进或触发顶层切换。
func advance() -> void:
	if is_instance_valid(_player) and not _paused and not get_tree().paused:
		_player.advance_on_click()


## 宿主暂停只冻结当前Timer/Tween；恢复保留本帧与剩余时间。
func set_paused(paused: bool) -> void:
	_paused = paused
	if is_instance_valid(_player):
		if paused:
			_player.pause_playback()
		else:
			_player.resume_playback()
	if _tween != null:
		if paused:
			_tween.pause()
		else:
			_tween.play()


## 移除旧控制器及Tween，重复播放不保留上一次完成回调。
func stop() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if is_instance_valid(_player):
		_player.pause_playback()
		_player.panel_display_requested.disconnect(_show_frame)
		_player.playback_completed.disconnect(_on_completed)
		_player.queue_free()
	_player = null


## 仍用原图与ComicFrame原坐标，等比舞台保证不同屏比例保持完整。
func _show_frame(number: int) -> void:
	if _tween != null:
		_tween.kill()
	for child: Node in _canvas.get_children():
		if child != _caption:
			_canvas.remove_child(child)
			child.queue_free()
	var frame: ComicFrame = _sequence.frames[number - 1]
	_tween = create_tween().set_parallel(true)
	for index: int in frame.textures.size():
		var layer := TextureRect.new()
		layer.texture = frame.textures[index]
		layer.size = layer.texture.get_size()
		layer.position = frame.positions[index] + frame.motion_offset
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.modulate.a = 0.0
		_canvas.add_child(layer)
		_tween.tween_property(layer, "modulate:a", 1.0, frame.reveal_seconds)
		_tween.tween_property(layer, "position", frame.positions[index], frame.reveal_seconds)
	_canvas.move_child(_caption, -1)
	_caption.text = frame.text
	_caption.position = frame.text_position
	_caption.size = frame.text_size
	print("PTF05_ENDING_FRAME ", number, "/", _sequence.frames.size(), " source=", frame.textures[0].resource_path)


## 演出层只通知完成一次；保存和路由仍归A。
func _on_completed() -> void:
	sequence_finished.emit(&"completed")


## 视口变化只调整舞台，原Resource保持只读。
func _fit_canvas() -> void:
	if not is_inside_tree() or _canvas == null:
		return
	var factor: float = minf(size.x / CANVAS_SIZE.x, size.y / CANVAS_SIZE.y)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (size - CANVAS_SIZE * factor) * 0.5


## 可触摸/鼠标快进，输入只在本演出Control上消费。
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		accept_event()
		advance()


## 离树丢弃局部演出，不生成完成或跳转事实。
func _exit_tree() -> void:
	stop()
