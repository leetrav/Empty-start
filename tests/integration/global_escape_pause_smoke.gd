extends Node
var _failures: int = 0
var _shots: String = "D:/src/playtest-20261020/pause-evidence"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().title = "Global Esc pause verification"
	get_window().size = Vector2i(1280, 720)
	get_tree().current_scene = null
	DirAccess.make_dir_recursive_absolute(_shots)
	_run.call_deferred()
	get_tree().create_timer(40.0).timeout.connect(func():
		SettingsManager.set_fullscreen(false)
		get_tree().quit(2)
	)

func _settle() -> void:
	while SceneRouter.is_transitioning():
		await get_tree().process_frame
	await get_tree().process_frame

func _pause_menu() -> Node:
	var found: Array[Node] = []
	for node: Node in get_tree().current_scene.find_children("*", "CanvasLayer", true, false):
		var script: Script = node.get_script() as Script
		if script != null and script.resource_path == SceneRouter.PAUSE_SCRIPT_PATH:
			found.append(node)
	_check(found.size() == 1, "exactly one pause menu: " + get_tree().current_scene.scene_file_path)
	return found[0] if not found.is_empty() else null

# 通过Godot真实输入分发发送Esc，不直接调用暂停函数。
func _escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame

func _exercise(label: String) -> void:
	var scene: Node = get_tree().current_scene
	var menu: Node = _pause_menu()
	await _escape()
	_check(get_tree().paused and menu.get_node("%Overlay").visible, label + " Esc opens pause")
	var before: float = AudioManager.get_music_position()
	await get_tree().create_timer(0.18).timeout
	_check(absf(AudioManager.get_music_position() - before) < 0.1, label + " music clock frozen")
	_check(get_tree().current_scene == scene, label + " Esc does not leave page")
	if scene is ComicPlayer:
		_check(scene.get("_paused"), "comic explicitly paused")
		await _capture("comic_paused")
	await _escape()
	_check(not get_tree().paused and not menu.get_node("%Overlay").visible, label + " Esc resumes")
	if scene is ComicPlayer:
		_check(not scene.get("_paused"), "comic resumes without ending")

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots.path_join(label + ".png"))

func _run() -> void:
	SceneRouter.goto_main_menu()
	await _settle()
	await _exercise("title")
	SceneRouter.goto_comic(&"intro")
	await _settle()
	await _exercise("comic")
	SaveManager.new_game()
	SceneRouter.goto_identity_setup()
	await _settle()
	await _exercise("name / identity")
	SaveManager.data.identity_id = IdentityOptions.CARDS[0].identity_id
	SaveManager.data.tendency_state.initialize_from_identity_option(IdentityOptions.CARDS[0])
	SceneRouter.goto_opening_room()
	await _settle()
	await _exercise("opening room")
	SceneRouter.goto_game()
	await _settle()
	await _exercise("battle")
	SceneRouter.goto_saved_ending({"scripture": {"is_empty": true, "rows": []}, "religion_name": "全局暂停验收"})
	await _settle()
	await _exercise("ending")
	# 复现用户的全屏结局页：Esc后在同一暂停设置面板关闭全屏。
	SettingsManager.set_fullscreen(true)
	await get_tree().process_frame
	await _escape()
	_check(get_tree().paused, "fullscreen ending can pause")
	var menu: Node = _pause_menu()
	await _capture("ending_fullscreen_paused")
	menu.get_node("%SettingsButton").pressed.emit()
	var settings: SettingsPanel = menu.get_node("%SettingsPanel") as SettingsPanel
	_check(settings.visible, "pause opens settings while paused")
	settings.get_node("%FullscreenCheck").set_pressed(false)
	await get_tree().process_frame
	_check(not SettingsManager.fullscreen and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "settings exits fullscreen")
	await _escape()
	_check(get_tree().paused and not settings.visible, "Esc closes settings but retains pause")
	await _capture("ending_windowed_paused")
	menu.get_node("%MainMenuButton").pressed.emit()
	await _settle()
	_check(not get_tree().paused and get_tree().current_scene.scene_file_path == SceneRouter.MAIN_MENU_SCENE_PATH, "pause can return to usable title")
	_check(not bool(AudioManager.get("_music_paused")), "return clears music pause state")
	print("GLOBAL_PAUSE_DONE failures=", _failures)
	get_tree().quit(_failures)

func _check(ok: bool, message: String) -> void:
	print("GLOBAL_PAUSE ", "PASS " if ok else "FAIL ", message)
	if not ok:
		_failures += 1
