class_name ComicPlayer
extends Control

signal playback_finished(reason: StringName)

var _paused: bool = false
var _page_sound: AudioStreamPlayer
var _act: String = ""
var _writing_elapsed: float = 0.0
var _writing_tick: float = 0.0

const OPENING: ComicSequence = preload("res://data/comics/opening.tres")
const ENDING: ComicSequence = preload("res://data/comics/ending.tres")
const CANVAS_SIZE := Vector2(1920, 1080)

var _canvas: Control
var _caption: Label
var _control: ComicPanelPlaybackControl
var _sequence: ComicSequence
var _layers: Array[TextureRect] = []
var _animation: Tween
var _sound: AudioStreamPlayer
var _frame: ComicFrame
var _text_elapsed: float = 0.0
var _finished: bool = false
var _kind: StringName
var _record_first_view: bool = false

# 路由只传播放目的；场景内建立独立演出节点并复用 ID-12 控制器。
func _ready() -> void:
	_kind = SceneRouter.comic_kind
	_record_first_view = SceneRouter.comic_record_first_view
	# 首次启动连续播放六幕；菜单保留前后两部分的独立回看。
	_sequence = ComicSequence.new()
	if _kind == &"intro":
		_sequence.frames.append_array(OPENING.frames)
		_sequence.frames.append_array(ENDING.frames)
	else:
		_sequence.frames.append_array(ENDING.frames if _kind == &"ending" else OPENING.frames)
	var background := ColorRect.new()
	background.color = Color(0.07, 0.07, 0.025)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_canvas = Control.new()
	_canvas.size = CANVAS_SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 36)
	_caption.add_theme_color_override("font_color", Color.WHITE)
	_caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	_caption.add_theme_constant_override("shadow_offset_x", 3)
	_caption.add_theme_constant_override("shadow_offset_y", 3)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_caption)
	resized.connect(_fit_canvas)
	_fit_canvas()
	_control = ComicPanelPlaybackControl.new()
	_control.panel_count = _sequence.frames.size()
	_control.auto_complete_last_panel = true
	for frame in _sequence.frames:
		# 自动结束须给全部文字和读后停顿留出时间。
		_control.panel_intervals_seconds.append(maxf(frame.seconds, frame.text.length() / maxf(1.0, frame.characters_per_second) + 1.0))
	_control.panel_display_requested.connect(_show_frame)
	_control.playback_completed.connect(_finish.bind(&"completed"))
	add_child(_control)
	if not start_playback():
		push_error("ComicPlayer: 播放配置为空或控制器未就绪。")
		SceneRouter.goto_main_menu()

# 独立场景启动共用计时控制器。
func start_playback() -> bool:
	return _control.start_playback()

func get_playback_control() -> ComicPanelPlaybackControl:
	return _control

# 隐藏页面时冻结计时、动画及逐字进度，回到页面后继续。
func set_playback_paused(value: bool) -> void:
	_paused = value
	if value:
		_control.pause_playback()
		if _animation != null:
			_animation.pause()
		if is_instance_valid(_sound):
			_sound.stop()
	else:
		_control.resume_playback()
		if _animation != null:
			_animation.play()

# 固定原图坐标，以等比缩放及居中留边适配任意窗口。
func _fit_canvas() -> void:
	if _canvas == null:
		return
	var factor := minf(size.x / CANVAS_SIZE.x, size.y / CANVAS_SIZE.y)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (size - CANVAS_SIZE * factor) * 0.5

# 保留已显示的相同拆图，只对本格新增层做淡入及轻微移动。
func _show_frame(number: int) -> void:
	_stop_animation_and_sound()
	_frame = _sequence.frames[number - 1]
	var common: int = 0
	while common < _layers.size() and common < _frame.textures.size():
		if _layers[common].texture != _frame.textures[common] or _layers[common].position != _frame.positions[common]:
			break
		common += 1
	while _layers.size() > common:
		var old := _layers.pop_back() as TextureRect
		_canvas.remove_child(old)
		old.queue_free()
	_animation = create_tween().set_parallel(true)
	for index in range(common, _frame.textures.size()):
		var layer := TextureRect.new()
		layer.texture = _frame.textures[index]
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.size = layer.texture.get_size()
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.position = _frame.positions[index] + _frame.motion_offset
		layer.modulate.a = 0.0
		_canvas.add_child(layer)
		_layers.append(layer)
		_animation.tween_property(layer, "position", _frame.positions[index], _frame.reveal_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_animation.tween_property(layer, "modulate:a", 1.0, _frame.reveal_seconds)
	_canvas.move_child(_caption, -1)
	_caption.text = _frame.text
	_caption.position = _frame.text_position
	_caption.size = _frame.text_size
	_caption.visible_characters = 0
	_text_elapsed = 0.0
	_sound = AudioManager.create_event_player(_frame.writing_event, self)
	_writing_elapsed = 0.0
	_writing_tick = 0.0
	var next_act := _frame.textures[-1].resource_path.get_base_dir().get_file()
	if not _act.is_empty() and next_act != _act:
		_page_sound = AudioManager.create_event_player(&"comic_page", self)
		if is_instance_valid(_page_sound):
			AudioManager.play_event_player(_page_sound)
	_act = next_act

# 空台词保持纯画面；正式台词配置后逐字推进，声音由场景独占。
func _process(delta: float) -> void:
	if _paused or _finished or _frame == null:
		return
	# 台词未交付时用显现期间的短打字声展示声音链路，不虚构剧情。
	if _frame.text.is_empty():
		_writing_elapsed += delta
		_writing_tick += delta
		if _writing_elapsed <= _frame.reveal_seconds and _writing_tick >= 0.12:
			_writing_tick = 0.0
			if is_instance_valid(_sound):
				AudioManager.play_event_player(_sound)
		return
	if _caption.visible_characters >= _frame.text.length():
		return
	_text_elapsed += delta
	var next_count := mini(_frame.text.length(), int(_text_elapsed * _frame.characters_per_second))
	if next_count > _caption.visible_characters:
		_caption.visible_characters = next_count
		if is_instance_valid(_sound):
			AudioManager.play_event_player(_sound)

# 任意非重复按键快进分镜；Esc 退出演出返回菜单。
func _input(event: InputEvent) -> void:
	if _finished or _paused or not is_visible_in_tree():
		return
	# 场景切换会立即使当前节点离树，先消费本次有效输入再执行路由。
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE:
			_finish(&"exited")
		else:
			advance()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		advance()
	elif event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()
		advance()
	else:
		return

# 快进先补全当前文字，随后推进分镜；末格快进结束整段。
func advance() -> void:
	if _finished or _paused or _frame == null:
		return
	if _caption.visible_characters < _frame.text.length():
		_caption.visible_characters = _frame.text.length()
		if is_instance_valid(_sound):
			_sound.stop()
		return
	_control.advance_on_click()

# 观看记录与路由只在明确完成或退出时更新，离树不会产生观看事实。
func _finish(reason: StringName) -> void:
	if _finished:
		return
	_finished = true
	_control.pause_playback()
	_stop_animation_and_sound()
	if _record_first_view and _kind == &"intro":
		SettingsManager.mark_opening_comic_seen()
	playback_finished.emit(reason)
	var error := SceneRouter.goto_main_menu()
	if error != OK:
		push_error("ComicPlayer: 返回主菜单失败：%s" % error_string(error))

# 中断时停止本场景拥有的动画及音频，不影响其他播放池。
func _stop_animation_and_sound() -> void:
	if _animation != null:
		_animation.kill()
		_animation = null
	if is_instance_valid(_sound):
		_sound.stop()
		_sound.queue_free()
		_sound = null
	if is_instance_valid(_page_sound):
		_page_sound.stop()
		_page_sound.queue_free()
		_page_sound = null
	# 快进中断动画时使已显示层回到本格的最终位置。
	if _frame != null:
		for index in range(_layers.size()):
			_layers[index].position = _frame.positions[index]
			_layers[index].modulate.a = 1.0

func _exit_tree() -> void:
	# 离树只清理，不写观看标记。
	_stop_animation_and_sound()
