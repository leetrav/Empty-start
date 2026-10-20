extends Node

# 当前音乐已切换或停止的事实，供场景取消过时的音乐请求。
signal music_changed(event_id: StringName)
# 击破静音请求完成后通知调用方；中途被新音乐请求替代时不发送。
signal music_silenced
# 只报告池播放器或场景独占播放器已开始播放的事实。
signal event_played(event_id: StringName, player: AudioStreamPlayer)

const SFX_PLAYER_COUNT: int = 8
const UI_PLAYER_COUNT: int = 4
const UI_BUTTON_AUDIO_META := &"audio_manager_ui_event"
const UI_SLIDER_AUDIO_META := &"audio_manager_ui_slider_event"
const UI_SELECTION_AUDIO_META := &"audio_manager_ui_selection"
const DIALOGUE_VOICE_SYNTHESIZER: Script = preload("res://core/audio/dialogue_voice_synthesizer.gd")
const VOICE_PRIORITY_EVENTS: Array[StringName] = [
	&"ui_error", &"ui_name_confirm", &"ui_identity_confirm", &"oracle_confirm",
	&"barrage_spawn", &"repeat_batch", &"attack_ready", &"attack_fire", &"hit_trap", &"trait_split",
	&"tier_up", &"pk_push_big", &"contradiction_start", &"contradiction_break",
	&"divine_descent_start", &"divine_descent_lock", &"live_like_burst",
]

const MUSIC_BUS_NAME: StringName = &"Music"
const SFX_BUS_NAME: StringName = &"SFX"
const UI_BUS_NAME: StringName = &"UI"
const AUDIO_EVENT_CONFIG: AudioEventConfig = preload("res://data/shared/audio_event_config.tres")
const FormalAudioConsumer = preload("res://data/shared/formal_sheet_runtime_consumer.gd")

# 通过同一 Resource 引用读取字段，避免 const Resource 属性在解析期折叠为旧值。
var _audio_config: AudioEventConfig = AUDIO_EVENT_CONFIG
var _music_player: AudioStreamPlayer
var _outgoing_music_player: AudioStreamPlayer
var _music_event_id: StringName = &""
var _music_paused: bool = false
var _music_event_gain: float = 1.0
var _outgoing_event_gain: float = 1.0
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
var _dialogue_voice_player: AudioStreamPlayer
var _dialogue_voice_music_ducked: bool = false
var _voice_priority_queue: Array[StringName] = []
var _last_ui_event_frame: int = -1
var _last_ui_event_stream_path: String = ""
var _last_selection_msec: int = -1000
var _silent_ui_focus: bool = false
var _play_sequence: int = 0
var _loop_events: Dictionary = {}


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
	# 重要主播声音使用独立播放器，不和短点击音效争抢UI池。
	_dialogue_voice_player = _create_player("DialogueVoicePlayer", SFX_BUS_NAME, sfx_bus_available)
	_dialogue_voice_player.volume_db = 3.0
	_dialogue_voice_player.finished.connect(_on_dialogue_voice_finished)
	# Autoload 先于菜单和身份场景就绪，正式表音效从第一处玩家交互起生效。
	FormalAudioConsumer.new().register_audio_events(self)
	# 所有真实按钮统一消费ui_click；节点动态进入场景树时也立即绑定。
	var scene_tree: SceneTree = get_tree()
	if not scene_tree.node_added.is_connected(_on_ui_node_added):
		scene_tree.node_added.connect(_on_ui_node_added)
	_bind_ui_buttons_in_subtree(scene_tree.root)


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
	set_music_paused(false)
	_music_event_id = &""
	_music_event_gain = 1.0
	_apply_music_gains()
	_music_player.pitch_scale = 1.0
	_music_player.stream = stream
	_music_player.play()
	music_changed.emit(_music_event_id)


func stop_music() -> void:
	stop_dialogue_voice()
	set_music_paused(false)
	_music_event_id = &""
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
	music_changed.emit(&"")


# 按 AU-01 音乐事件请求主音乐；首次淡入，换曲时交叉切换。
func change_music(event_id: StringName, cross_fade_seconds: float = -1.0, from_position: float = 0.0, fade_in_seconds: float = -1.0, overlap: bool = true) -> bool:
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
		_outgoing_event_gain = _music_event_gain
		_music_gain = 0.0
		_music_player.bus = MUSIC_BUS_NAME
		_music_player.stream = event.stream
		_music_player.pitch_scale = randf_range(minf(event.pitch_min, event.pitch_max), maxf(event.pitch_min, event.pitch_max))
		_music_event_gain = db_to_linear(event.volume_db)
		_music_player.play(maxf(from_position, 0.0))
		_music_player.stream_paused = _music_paused
	var has_outgoing_music: bool = _outgoing_music_player.stream != null and _outgoing_music_player.is_playing()
	var duration: float = _audio_config.music_cross_fade_seconds if has_outgoing_music else _audio_config.music_fade_in_seconds
	if not has_outgoing_music and fade_in_seconds >= 0.0:
		duration = fade_in_seconds
	if has_outgoing_music and cross_fade_seconds >= 0.0:
		duration = cross_fade_seconds
	if has_outgoing_music and not overlap and duration > 0.0:
		_tween_music_without_overlap(duration)
	else:
		_tween_music_gains(1.0, duration, _finish_music_change)
	_music_event_id = event_id
	music_changed.emit(event_id)
	return true


# 返回音频时钟及当前事件；场景只订阅事实，不直接访问播放器。
func get_music_event_id() -> StringName:
	return _music_event_id


func get_music_position() -> float:
	if not is_instance_valid(_music_player) or _music_player.stream == null:
		return 0.0
	var position: float = _music_player.get_playback_position()
	if not _music_paused and _music_player.playing:
		position += AudioServer.get_time_since_last_mix()
	return fposmod(position, _music_player.stream.get_length()) if _music_player.stream.get_length() > 0.0 else 0.0


func get_music_length() -> float:
	return _music_player.stream.get_length() if is_instance_valid(_music_player) and _music_player.stream != null else 0.0


# OGG可只循环中间伴奏；音乐时钟回绕应扣除不再重复的开头。
func get_music_loop_offset() -> float:
	if is_instance_valid(_music_player) and _music_player.stream is AudioStreamOggVorbis:
		var stream: AudioStreamOggVorbis = _music_player.stream
		return stream.loop_offset if stream.loop else 0.0
	return 0.0


# 两首过渡音乐及淡变一起暂停，恢复时不重头播放，不改玩家Music总线。
func set_music_paused(paused: bool) -> void:
	if paused:
		stop_dialogue_voice()
	_music_paused = paused
	for player: AudioStreamPlayer in [_music_player, _outgoing_music_player]:
		if is_instance_valid(player):
			player.stream_paused = paused
	for tween: Tween in [_music_tween, _duck_tween]:
		# 完成回调所在帧Tween仍可能valid，但已不能play；只恢复仍有循环的暂停Tween。
		if tween != null and tween.is_valid() and tween.get_loops_left() != 0:
			if paused:
				tween.pause()
			elif not tween.is_running():
				tween.play()

# 仅场景交接的短遮幕期间保持两路音乐及已有增益Tween运行；Esc仍显式暂停。
# 结束交接恢复原继承模式，不把音效池或战斗系统改成常驻运行。
func set_music_handoff_processing(enabled: bool) -> void:
	for player: AudioStreamPlayer in [_music_player, _outgoing_music_player]:
		if is_instance_valid(player):
			player.process_mode = Node.PROCESS_MODE_ALWAYS if enabled else Node.PROCESS_MODE_INHERIT
	for tween: Tween in [_music_tween, _duck_tween]:
		if tween != null and tween.is_valid():
			tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS if enabled else Tween.TWEEN_PAUSE_BOUND)


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
		_music_player.volume_linear = _music_gain * _duck_gain * _music_event_gain
	if is_instance_valid(_outgoing_music_player):
		_outgoing_music_player.volume_linear = _outgoing_gain * _duck_gain * _outgoing_event_gain


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
	if _music_paused:
		_music_tween.pause()


# 不同旋律的剧情引子接战斗时，先停止旧曲再起新曲，避免交叉叠音。
# 新曲在静音状态保留音频时钟；暂停/取消沿用同一个音乐Tween。
func _tween_music_without_overlap(duration: float) -> void:
	_cancel_music_tween()
	_music_gain = 0.0
	_music_tween = create_tween()
	_music_tween.tween_property(self, "_outgoing_gain", 0.0, duration * 0.5)
	_music_tween.tween_callback(_stop_outgoing_music)
	_music_tween.tween_property(self, "_music_gain", 1.0, duration * 0.5)
	_music_tween.tween_callback(_finish_music_change)
	if _music_paused:
		_music_tween.pause()


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
	if _music_paused:
		_duck_tween.pause()


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
	if _dialogue_voice_is_playing():
		# 主播拟声优先；普通点击和感染让位，关键结果等短句结束后补播。
		if event_id in [&"ui_click", &"ui_identity_switch", &"hit_normal"]:
			return
		if event_id in VOICE_PRIORITY_EVENTS:
			if _voice_priority_queue.size() < 8:
				_voice_priority_queue.append(event_id)
			return
	if event.audio_type == AudioEvent.AudioType.UI and event_id != &"ui_menu_hover":
		# 供延迟通用按钮绑定识别同帧已播放的专用反馈；独立业务事件仍各自播放。
		_last_ui_event_frame = Engine.get_process_frames()
		_last_ui_event_stream_path = event.stream.resource_path

	match event.audio_type:
		AudioEvent.AudioType.MUSIC:
			change_music(event_id)
		AudioEvent.AudioType.SFX:
			_play_configured_event(event, _sfx_players, _sfx_play_order, SFX_BUS_NAME)
		AudioEvent.AudioType.UI:
			_play_configured_event(event, _ui_players, _ui_play_order, UI_BUS_NAME)
		_:
			push_error("AudioManager: audio event '%s' has an unsupported audio type." % str(event_id))


## 正式数据表加载后按稳定 ID 覆盖单个事件，保留其他系统的现有音频入口。
func register_event(event: AudioEvent) -> bool:
	if event == null or event.event_id == &"" or event.stream == null:
		return false
	for index: int in range(_audio_config.events.size()):
		var current: AudioEvent = _audio_config.events[index]
		if current != null and current.event_id == event.event_id:
			_audio_config.events[index] = event
			return true
	_audio_config.events.append(event)
	return true


# UI 拥有者在创建按钮时绑定稳定音效 ID；同一按钮重复绑定保持一次播放。
func bind_ui_button(button: BaseButton, event_id: StringName = &"ui_click") -> bool:
	if button == null:
		return false
	var event: AudioEvent = _audio_config.find_event(event_id)
	if event == null or event.stream == null or event.audio_type != AudioEvent.AudioType.UI:
		return false
	# 公共扫描先挂通用音；Owner随后传专用事件时替换同一个监听，避免双播。
	if button.has_meta(UI_BUTTON_AUDIO_META):
		var previous: Dictionary = button.get_meta(UI_BUTTON_AUDIO_META, {})
		if StringName(previous.get("event_id", "")) == event_id:
			return true
		var previous_callback: Callable = previous.get("callback", Callable())
		if previous_callback.is_valid() and button.pressed.is_connected(previous_callback):
			button.pressed.disconnect(previous_callback)
	var callback: Callable = _on_bound_ui_button_pressed.bind(button, event_id)
	button.pressed.connect(callback)
	button.set_meta(UI_BUTTON_AUDIO_META, {"event_id": event_id, "callback": callback})
	return true


# 自动安置焦点保持静音，真实鼠标进入和键盘导航继续播放反馈。
func focus_ui_silently(control: Control) -> void:
	# 页面初始/回退自动安置焦点不是玩家选定，仍保留后续鼠标进入反馈。
	var previous := _silent_ui_focus
	_silent_ui_focus = true
	control.grab_focus()
	_silent_ui_focus = previous


# 页面按需接入选定声；鼠标与焦点合并成同一个激活状态，不重复连接。
func bind_ui_selection(button: BaseButton) -> void:
	if button == null or button.has_meta(UI_SELECTION_AUDIO_META):
		return
	button.set_meta(UI_SELECTION_AUDIO_META, {"mouse": false, "focus": false})
	button.mouse_entered.connect(_on_ui_selection_changed.bind(button, "mouse", true))
	button.mouse_exited.connect(_on_ui_selection_changed.bind(button, "mouse", false))
	button.focus_entered.connect(_on_ui_selection_changed.bind(button, "focus", true))
	button.focus_exited.connect(_on_ui_selection_changed.bind(button, "focus", false))
	button.visibility_changed.connect(_on_ui_selection_visibility.bind(button))


# 隐藏步骤清掉鼠标状态，避免再次显示后第一次进入没有声音。
func _on_ui_selection_visibility(button: BaseButton) -> void:
	if not button.is_visible_in_tree():
		button.set_meta(UI_SELECTION_AUDIO_META, {"mouse": false, "focus": false})


func _on_ui_selection_changed(button: BaseButton, source: String, active: bool) -> void:
	var state: Dictionary = button.get_meta(UI_SELECTION_AUDIO_META)
	var was_active: bool = state.mouse or state.focus
	if source == "focus" and active and _silent_ui_focus:
		state.focus = false
		button.set_meta(UI_SELECTION_AUDIO_META, state)
		return
	state[source] = active
	button.set_meta(UI_SELECTION_AUDIO_META, state)
	if was_active or not active or button.disabled or not button.is_visible_in_tree() or not button.can_process() or SceneRouter.is_transitioning():
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_selection_msec < 70:
		return
	_last_selection_msec = now
	play_event(&"ui_menu_hover")


## 递归绑定当前界面和后续动态添加的 BaseButton，不碰装饰性Control。
func _bind_ui_buttons_in_subtree(root: Node) -> void:
	if root is BaseButton:
		bind_ui_button(root)
	elif root is Slider:
		_bind_ui_slider(root)
	for child: Node in root.get_children():
		_bind_ui_buttons_in_subtree(child)


func _on_ui_node_added(node: Node) -> void:
	# SceneTree对进入树的子节点逐一发出node_added；只处理当前节点，避免反复扫描整棵子树。
	if node is BaseButton:
		bind_ui_button(node)
	elif node is Slider:
		_bind_ui_slider(node)


func _bind_ui_slider(slider: Slider) -> void:
	if slider.has_meta(UI_SLIDER_AUDIO_META):
		return
	if not slider.drag_ended.is_connected(_on_ui_slider_drag_ended):
		slider.drag_ended.connect(_on_ui_slider_drag_ended)
	slider.set_meta(UI_SLIDER_AUDIO_META, true)


func _on_ui_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		play_ui_click()


# 延后一帧业务回调先执行；相同UI事件已播放时，通用音不再重复。
func _on_bound_ui_button_pressed(_button: BaseButton, event_id: StringName) -> void:
	var input_frame: int = Engine.get_process_frames()
	call_deferred("_play_bound_ui_button_event", event_id, input_frame)


func _play_bound_ui_button_event(event_id: StringName, input_frame: int) -> void:
	if event_id == &"ui_click":
		var event: AudioEvent = _audio_config.find_event(event_id)
		if event == null or event.stream == null:
			return
		# 名字/身份确认等业务音已反馈本次点击时，不再叠通用点击；悬停不占此标记。
		if _last_ui_event_frame == input_frame:
			return
	play_event(event_id)


## 自定义点击区域和普通按钮共用同帧去重，覆盖触屏鼠标映射的同一逻辑输入。
func play_ui_click() -> void:
	var event: AudioEvent = _audio_config.find_event(&"ui_click")
	if event == null or event.stream == null:
		return
	var input_frame: int = Engine.get_process_frames()
	if _last_ui_event_frame == input_frame and _last_ui_event_stream_path == event.stream.resource_path:
		return
	play_event(&"ui_click")


## 按发言文本合成短拟声；新气泡会截断旧声并短暂压低BGM。
func play_dialogue_voice(speaker_id: StringName, text: String) -> bool:
	if _music_paused or text.strip_edges().is_empty() or not is_instance_valid(_dialogue_voice_player):
		return false
	var stream: AudioStreamWAV = DIALOGUE_VOICE_SYNTHESIZER.build_stream(text, speaker_id)
	if stream == null or not _ensure_audio_bus(SFX_BUS_NAME):
		return false
	if _dialogue_voice_is_playing():
		# 新句替换旧句，但整段对白连续压低BGM，不在句间突然恢复。
		_dialogue_voice_player.stop()
		_dialogue_voice_player.stream = null
	_dialogue_voice_player.stream = stream
	_dialogue_voice_player.bus = SFX_BUS_NAME
	if not _dialogue_voice_music_ducked:
		_dialogue_voice_music_ducked = true
		duck_music()
	_dialogue_voice_player.play()
	return true


## 气泡被切走、暂停、重开或离场时立即停止拟声并恢复BGM。
func stop_dialogue_voice(flush_priority_events: bool = false) -> void:
	if is_instance_valid(_dialogue_voice_player):
		_dialogue_voice_player.stop()
		_dialogue_voice_player.stream = null
	if _dialogue_voice_music_ducked:
		_dialogue_voice_music_ducked = false
		restore_music()
	if flush_priority_events:
		_flush_voice_priority_events()
	else:
		_voice_priority_queue.clear()


func _dialogue_voice_is_playing() -> bool:
	return is_instance_valid(_dialogue_voice_player) and _dialogue_voice_player.is_playing()


func _on_dialogue_voice_finished() -> void:
	stop_dialogue_voice(true)


func _flush_voice_priority_events() -> void:
	var queued_events: Array[StringName] = _voice_priority_queue.duplicate()
	_voice_priority_queue.clear()
	for event_id: StringName in queued_events:
		play_event(event_id)


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


## 正式事件在实际播放器上应用表内音量、音高和循环字段。
func _play_configured_event(
		event: AudioEvent, players: Array[AudioStreamPlayer], play_order: Array[int], bus_name: StringName
	) -> void:
	if event == null or event.stream == null or not _ensure_audio_bus(bus_name):
		return
	var player_index := _find_pool_player_index(players, play_order)
	if player_index < 0:
		return
	var player: AudioStreamPlayer = players[player_index]
	player.stop()
	_loop_events.erase(player.get_instance_id())
	player.bus = bus_name
	player.stream = event.stream
	player.volume_db = event.volume_db
	player.pitch_scale = randf_range(minf(event.pitch_min, event.pitch_max), maxf(event.pitch_min, event.pitch_max))
	player.play()
	play_order[player_index] = _play_sequence
	_play_sequence += 1
	if event.loop:
		_loop_events[player.get_instance_id()] = event
		if not player.finished.is_connected(_on_configured_event_finished):
			player.finished.connect(_on_configured_event_finished)
	event_played.emit(event.event_id, player)


func _on_configured_event_finished() -> void:
	# finished 不带发送者；按播放器池检查循环事件，事件替换后旧循环自动失效。
	for player: AudioStreamPlayer in _sfx_players + _ui_players:
		var event: AudioEvent = _loop_events.get(player.get_instance_id())
		if event != null and player.stream == event.stream and not player.is_playing():
			player.play()


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

# 短剧情声音由调用场景独占，退出时可停止，避免干扰全局音效池。
func create_event_player(event_id: StringName, owner_node: Node) -> AudioStreamPlayer:
	var event: AudioEvent = _audio_config.find_event(event_id)
	if event == null or event.stream == null or event.audio_type == AudioEvent.AudioType.MUSIC:
		push_warning("AudioManager: 剧情音效事件不可用：%s" % event_id)
		return null
	var bus: StringName = UI_BUS_NAME if event.audio_type == AudioEvent.AudioType.UI else SFX_BUS_NAME
	if not _ensure_audio_bus(bus):
		return null
	var player := AudioStreamPlayer.new()
	player.name = "ComicWritingPlayer"
	player.bus = bus
	player.stream = event.stream
	player.volume_db = event.volume_db
	player.pitch_scale = randf_range(minf(event.pitch_min, event.pitch_max), maxf(event.pitch_min, event.pitch_max))
	player.set_meta("audio_event_id", event_id)
	owner_node.add_child(player)
	return player


# 播放场景独占的正式事件，同时发布实际开始事实；退出仍由原 UI 停止/释放。
func play_event_player(player: AudioStreamPlayer) -> bool:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return false
	var event_id: StringName = StringName(player.get_meta("audio_event_id", &""))
	var event: AudioEvent = _audio_config.find_event(event_id)
	if event == null or event.stream == null or player.stream != event.stream:
		return false
	player.volume_db = event.volume_db
	player.pitch_scale = randf_range(minf(event.pitch_min, event.pitch_max), maxf(event.pitch_min, event.pitch_max))
	player.play()
	event_played.emit(event_id, player)
	return true
