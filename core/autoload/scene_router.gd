extends Node

signal transition_started(scene_path: String)
signal transition_finished(scene_path: String)
signal transition_failed(scene_path: String, error: Error)

const COMIC_SCENE_PATH: String = "res://ui/comic/comic_player.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://ui/main_menu/main_menu.tscn"
const IDENTITY_SETUP_SCENE_PATH: String = "res://ui/identity_setup/identity_setup.tscn"
const OPENING_ROOM_SCENE_PATH: String = "res://ui/rest/rest_opening_room.tscn"
const GAME_SCENE_PATH: String = "res://scenes/sandbox/sandbox_plan_b.tscn"
const ENDING_SCENE_PATH: String = "res://ui/ending/ending_page.tscn"
const PAUSE_MENU_PATH: String = "res://ui/pause_menu/pause_menu.tscn"
const PAUSE_SCRIPT_PATH: String = "res://ui/pause_menu/pause_menu.gd"
const LOADING_SCREEN: Script = preload("res://ui/loading_screen.gd")
const FADE_OUT_SECONDS: float = 0.20
const FADE_IN_SECONDS: float = 0.25
const MINIMUM_COVER_SECONDS: float = 0.12
const LIVE_MINIMUM_COVER_SECONDS: float = 0.6

var comic_kind: StringName = &"opening"
var comic_record_first_view: bool = false
# 集成夹具仍可显式替换游戏入口。
var game_scene_override: PackedScene
var _ending_session: EndingSession
var _saved_ending_display: Dictionary = {}
var _transitioning: bool = false
var _loading_layer: CanvasLayer
var _failure_dialog: AcceptDialog
var _loading_screen: Control
# 只有正式终局或其未完成存档可以建立此链；静态鸣谢/回看不建立完成资格。
var _completion_stage: StringName = &""
var _main_menu_scene: PackedScene

# 常驻层在暂停菜单和场景销毁期间继续工作，所有顶层入口共用同一过渡。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_loading_layer = CanvasLayer.new()
	_loading_layer.layer = 100
	add_child(_loading_layer)
	_loading_screen = LOADING_SCREEN.new() as Control
	_loading_screen.name = "LoadingScreen"
	_loading_layer.add_child(_loading_screen)
	_loading_screen.hide()
	_failure_dialog = AcceptDialog.new()
	_failure_dialog.title = "加载失败"
	_failure_dialog.ok_button_text = "返回主菜单"
	_failure_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_failure_dialog.confirmed.connect(goto_main_menu)
	_failure_dialog.close_requested.connect(goto_main_menu)
	add_child(_failure_dialog)
	# 初次F5/F6和此后每次切换都补齐同一暂停菜单，已有场景菜单继续复用。
	get_tree().scene_changed.connect(_ensure_global_pause)
	_ensure_global_pause.call_deferred()

# 鼠标由遮罩拦截，键盘也在最先进入的路由层消费，避免快进穿透下一页面。
func _input(_event: InputEvent) -> void:
	if _transitioning:
		get_viewport().set_input_as_handled()

func is_transitioning() -> bool:
	return _transitioning

func goto_comic(kind: StringName, record_first_view: bool = false) -> Error:
	if kind not in [&"intro", &"opening", &"ending"]:
		return ERR_INVALID_PARAMETER
	if kind == &"ending" and not SettingsManager.ending_replay_unlocked:
		return ERR_UNAUTHORIZED
	var error: Error = _request_scene(COMIC_SCENE_PATH)
	if error == OK:
		comic_kind = kind
		comic_record_first_view = record_first_view
	return error

func goto_main_menu() -> Error:
	if is_ending_performance_active():
		return ERR_BUSY
	return _request_scene(MAIN_MENU_SCENE_PATH)

func goto_identity_setup() -> Error:
	return _request_scene(IDENTITY_SETUP_SCENE_PATH)

func goto_opening_room() -> Error:
	return _request_scene(OPENING_ROOM_SCENE_PATH)

func goto_game() -> Error:
	return _request_scene(GAME_SCENE_PATH, game_scene_override)


# 原场景重开也走同一遮幕，动作必须同步返回bool；顶层开播继续走goto_game。
func prepare_live_attempt(action: Callable) -> Error:
	if _transitioning:
		return ERR_BUSY
	var current := get_tree().current_scene
	if current == null or current.scene_file_path != GAME_SCENE_PATH or not action.is_valid():
		return ERR_UNCONFIGURED
	_transitioning = true
	_run_live_attempt.call_deferred(action, current)
	return OK


# 保留当前战斗节点与周目资料，先完全遮住画面再执行原有重建逻辑。
func _run_live_attempt(action: Callable, owner_scene: Node) -> void:
	var was_paused := get_tree().paused
	get_tree().paused = true
	_loading_screen.set("pure_black", false)
	_loading_screen.call("reset_indicator")
	_loading_screen.set("show_indicator", true)
	_loading_screen.modulate.a = 0.0
	_loading_screen.show()
	transition_started.emit(GAME_SCENE_PATH)
	await _fade_to(1.0, FADE_OUT_SECONDS)
	if not is_instance_valid(owner_scene) or get_tree().current_scene != owner_scene or not action.is_valid():
		await _recover_transition(GAME_SCENE_PATH, ERR_UNCONFIGURED, was_paused)
		return
	var rebuilt: bool = action.call()
	# 原重开会恢复暂停菜单；在揭幕前再次冻结新尝试，不能在黑幕后跑计时。
	get_tree().paused = true
	if not rebuilt:
		await _recover_transition(GAME_SCENE_PATH, ERR_CANT_CREATE, was_paused)
		return
	await get_tree().create_timer(LIVE_MINIMUM_COVER_SECONDS, true, false, true).timeout
	_loading_screen.set("show_indicator", false)
	await _fade_to(0.0, FADE_IN_SECONDS)
	_loading_screen.hide()
	get_tree().paused = false
	_transitioning = false
	transition_finished.emit(GAME_SCENE_PATH)

# 请求被接受后保存显示参数；实际创建页面后再交付结局快照。
func goto_ending(session: EndingSession, play_epilogue: bool = false) -> Error:
	if session == null or not session.is_received():
		return ERR_INVALID_PARAMETER
	if _ending_session == session:
		return ERR_ALREADY_IN_USE
	var error: Error = _request_scene(COMIC_SCENE_PATH if play_epilogue else ENDING_SCENE_PATH)
	if error == OK:
		_ending_session = session
		_saved_ending_display.clear()
		if play_epilogue:
			_completion_stage = &"epilogue"
			comic_kind = &"epilogue"
			comic_record_first_view = false
		else:
			_completion_stage = &""
	return error

func _show_ending() -> void:
	var page := get_tree().current_scene as EndingPage
	if page != null and _ending_session != null:
		page.show_ending(_ending_session.get_display_data())
	elif page != null and not _saved_ending_display.is_empty():
		page.show_ending(_saved_ending_display)
	if page != null and _completion_stage == &"credits":
		page.start_credits_performance()

# 已完成周目只呈现保存的显示快照，不再次执行奖励。
func goto_saved_ending(display_data: Dictionary) -> Error:
	if display_data.is_empty() or not display_data.has("scripture"):
		return ERR_INVALID_DATA
	var error: Error = _request_scene(ENDING_SCENE_PATH)
	if error == OK:
		_ending_session = null
		_saved_ending_display = display_data.duplicate(true)
		_completion_stage = &""
	return error

# 仅恢复已保存的真实终局未完成标记；普通快照入口不能获得解锁资格。
func resume_ending_roll() -> Error:
	if SaveManager.data == null or not SaveManager.data.ending_roll_pending or SaveManager.data.ending_display_data.is_empty():
		return ERR_UNCONFIGURED
	var error := _request_scene(COMIC_SCENE_PATH)
	if error == OK:
		_ending_session = null
		_saved_ending_display = SaveManager.data.ending_display_data.duplicate(true)
		_completion_stage = &"epilogue"
		comic_kind = &"epilogue"
		comic_record_first_view = false
	return error

# 暂停菜单读取播放资格，仍保留继续/设置，不提供跳过片尾。
func is_ending_performance_active() -> bool:
	return _completion_stage in [&"epilogue", &"credits", &"title"]

func reload_current_scene() -> Error:
	var current: Node = get_tree().current_scene
	if current == null or current.scene_file_path.is_empty():
		return ERR_UNCONFIGURED
	return _request_scene(current.scene_file_path)

# 返回 OK 表示请求已接受；异步失败由 transition_failed 报告，恢复原页面和暂停状态。
func _request_scene(scene_path: String, override_scene: PackedScene = null) -> Error:
	if _transitioning:
		return ERR_BUSY
	# 片尾返回复用已加载的标题资源，避免再次后台读取；只缓存资源，不保留或复制菜单节点。
	if override_scene == null and scene_path == MAIN_MENU_SCENE_PATH:
		override_scene = _main_menu_scene
	if override_scene == null:
		if not ResourceLoader.exists(scene_path, "PackedScene"):
			push_error("SceneRouter: scene resource not found: %s" % scene_path)
			return ERR_FILE_NOT_FOUND
		# 本机 dummy renderer 后台读取战斗资源会停在 IN_PROGRESS；无窗口验证沿用同步读取。
		if DisplayServer.get_name() != "headless":
			var error: Error = ResourceLoader.load_threaded_request(scene_path, "PackedScene")
			if error != OK:
				return error
	_transitioning = true
	# 延后启动协程，保证调用方先保存漫画/结局参数及按钮状态。
	_run_transition.call_deferred(scene_path, override_scene)
	return OK

# 先绘出遮罩再取加载结果；只有后台读取完成才允许 get，避免在这里阻塞资源读取。
func _run_transition(scene_path: String, override_scene: PackedScene) -> void:
	var live_entry: bool = scene_path == GAME_SCENE_PATH
	var was_paused: bool = get_tree().paused
	var previous: Node = get_tree().current_scene
	var previous_path: String = previous.scene_file_path if previous != null else ""
	var comic_to_title: bool = previous_path == COMIC_SCENE_PATH and scene_path == MAIN_MENU_SCENE_PATH
	var credits_to_title: bool = previous_path == ENDING_SCENE_PATH and scene_path == MAIN_MENU_SCENE_PATH and _completion_stage == &"title"
	var movie_to_credits: bool = previous_path == COMIC_SCENE_PATH and scene_path == ENDING_SCENE_PATH and _completion_stage == &"credits"
	var epilogue_boundary: bool = (previous_path == COMIC_SCENE_PATH and scene_path == ENDING_SCENE_PATH) or (scene_path == COMIC_SCENE_PATH and comic_kind == &"epilogue")
	var cinematic: bool = comic_to_title or epilogue_boundary
	var leaving_title: bool = previous_path == MAIN_MENU_SCENE_PATH
	# 神谕→原结尾→制作组只交接同一播放器，树暂停不能造成可听见的音乐停顿。
	AudioManager.set_music_handoff_processing(epilogue_boundary and AudioManager.get_music_event_id()==EndingMusicPresenter.EVENT and not was_paused)
	_loading_screen.set("pure_black", epilogue_boundary or credits_to_title)
	# 漫画收尾和标题离场先让音乐随遮幕淡完，不能先暂停音频Tween造成突然静音。
	var music_exit: bool = (comic_to_title or leaving_title or credits_to_title) and not was_paused
	if not music_exit:
		get_tree().paused = true
	_loading_screen.call("reset_indicator")
	_loading_screen.set("show_indicator", live_entry)
	_loading_screen.modulate.a = 0.0
	_loading_screen.show()
	transition_started.emit(scene_path)
	if music_exit:
		AudioManager.fade_to_silence()
	var fade_out: float = 0.9 if movie_to_credits else (0.45 if cinematic else (0.30 if music_exit else FADE_OUT_SECONDS))
	await _fade_to(1.0, fade_out)
	get_tree().paused = true
	var cover_start: int = Time.get_ticks_msec()
	var scene: PackedScene = override_scene
	if scene == null and DisplayServer.get_name() == "headless":
		scene = ResourceLoader.load(scene_path, "PackedScene") as PackedScene
	elif scene == null:
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.THREAD_LOAD_IN_PROGRESS
		while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if Time.get_ticks_msec() - cover_start > 30000:
				await _recover_transition(scene_path, ERR_TIMEOUT, was_paused)
				return
			status = ResourceLoader.load_threaded_get_status(scene_path)
			_loading_screen.set("show_indicator", live_entry or Time.get_ticks_msec() - cover_start > 180)
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await get_tree().process_frame
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			scene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if scene == null:
		await _recover_transition(scene_path, ERR_CANT_OPEN, was_paused)
		return
	if scene_path == MAIN_MENU_SCENE_PATH:
		_main_menu_scene = scene
	var minimum_cover: float = LIVE_MINIMUM_COVER_SECONDS if live_entry else (0.6 if movie_to_credits else (0.25 if cinematic else MINIMUM_COVER_SECONDS))
	var remaining: float = minimum_cover - float(Time.get_ticks_msec() - cover_start) / 1000.0
	if remaining > 0.0:
		await get_tree().create_timer(remaining, true, false, true).timeout
	# 遮罩已完整渲染，实例化期间即使出现主线程峰值，也不会暴露空场景。
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	var error: Error = get_tree().change_scene_to_packed(scene)
	if error != OK:
		await _recover_transition(scene_path, error, was_paused)
		return
	await get_tree().scene_changed
	if scene_path == ENDING_SCENE_PATH:
		_show_ending()
	# 保持新页面暂停直到淡入完成，避免对白/自动计时在黑幕下提前消耗。
	_loading_screen.set("show_indicator", false)
	# 常驻黑幕揭开整个原菜单，包括背景、标题、按钮和光效；不创建第二份菜单。
	await _fade_to(0.0, 1.0 if credits_to_title else (0.60 if cinematic else FADE_IN_SECONDS))
	_loading_screen.hide()
	get_tree().paused = false
	AudioManager.set_music_handoff_processing(false)
	if credits_to_title:
		_commit_ending_completion()
	_transitioning = false
	transition_finished.emit(scene_path)

# 加载失败保留旧页面；允许玩家确认错误后继续操作，不让遮罩永久挡住输入。
func _recover_transition(scene_path: String, error: Error, was_paused: bool) -> void:
	# 加载失败不算播放完成；已落盘的pending使下次载入可重新完整播放。
	_completion_stage = &""
	push_error("SceneRouter: transition failed for %s: %s" % [scene_path, error_string(error)])
	await _fade_to(0.0, FADE_IN_SECONDS)
	_loading_screen.hide()
	get_tree().paused = was_paused
	AudioManager.set_music_handoff_processing(false)
	_transitioning = false
	transition_failed.emit(scene_path, error)
	_failure_dialog.dialog_text = "场景未能载入，请返回主菜单重试。"
	_failure_dialog.popup_centered()

func _fade_to(alpha: float, seconds: float) -> void:
	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	tween.tween_property(_loading_screen, "modulate:a", alpha, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

# 每个正式顶层页面恰有一套暂停入口；保留Sandbox现有重开及指针取消接线。
func _ensure_global_pause() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var pause: Node = null
	for candidate: Node in scene.find_children("*", "CanvasLayer", true, false):
		var script: Script = candidate.get_script() as Script
		if script != null and script.resource_path == PAUSE_SCRIPT_PATH:
			pause = candidate
			break
	if pause == null:
		var packed: PackedScene = load(PAUSE_MENU_PATH) as PackedScene
		if packed == null:
			push_error("SceneRouter: global pause scene could not be loaded")
			return null
		pause = packed.instantiate()
		scene.add_child(pause)
		pause.call("set_restart_available", false)
	var callback: Callable = Callable(self, "_on_global_pause_changed")
	if not pause.is_connected("paused_changed", callback):
		pause.connect("paused_changed", callback)
	return pause


# 标题选项复用当前页面的唯一暂停/设置实例，避免两套样式与重复菜单。
func open_title_settings() -> Node:
	if is_transitioning():
		return null
	var pause := _ensure_global_pause()
	if pause != null:
		pause.call("open_settings")
	return pause

# 树暂停冻结玩法；漫画还要冻结自己的逐字/动画计时，音乐共用现有暂停接口。
func _on_global_pause_changed(paused: bool) -> void:
	AudioManager.set_music_paused(paused)
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("set_playback_paused"):
		scene.call("set_playback_paused", paused)

# 后两幕播放结束后交付同一终局快照，不重新接收奖励或重播动画。
func finish_ending_epilogue() -> Error:
	var current := get_tree().current_scene as ComicPlayer
	if _completion_stage != &"epilogue" or current == null or comic_kind != &"epilogue":
		return ERR_UNCONFIGURED
	var error := _request_scene(ENDING_SCENE_PATH)
	if error == OK:
		_completion_stage = &"credits"
	return error

# 只有当前正常片尾页面的完成事实可以进入标题显现，重复回调被阶段守卫拒绝。
func finish_ending_credits(page: EndingPage) -> Error:
	if _completion_stage != &"credits" or page != get_tree().current_scene or page.get_credits_stage() != &"complete":
		return ERR_UNCONFIGURED
	var error := _request_scene(MAIN_MENU_SCENE_PATH)
	if error == OK:
		_completion_stage = &"title"
	return error

# 标题已完全显现才提交应用级事实；周目pending只在持久化成功后清除。
func _commit_ending_completion() -> void:
	var error := SettingsManager.mark_ending_replay_unlocked()
	if error == OK and SaveManager.data != null and SaveManager.data.ending_roll_pending:
		SaveManager.data.ending_roll_pending = false
		if SaveManager.save_game() != OK:
			SaveManager.data.ending_roll_pending = true
			push_error("SceneRouter: 片尾完成后的周目标记保存失败，下次读档将重播片尾。")
	elif error != OK:
		push_error("SceneRouter: 结局回放解锁保存失败，保留未完成存档供下次重试。")
	_completion_stage = &""
