extends Node
var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	get_window().size = Vector2i(1280, 720)
	get_tree().create_timer(35.0).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()

# 正式标题输入、旧高档配置和共享设置页的可见性/音乐回归。
func _run() -> void:
	_check(SceneRouter.goto_main_menu() == OK, "formal title route")
	while SceneRouter.is_transitioning(): await get_tree().process_frame
	await _wait()
	var title := get_tree().current_scene
	await _click(title.get_node("%SettingsButton"))
	var menu := title.find_child("PauseMenu", true, false)
	var panel: Control = menu.get_node("%SettingsPanel")
	_check(panel.is_visible_in_tree() and not title.get_node("%MenuActions").visible, "title directly opens shared artwork slider page")
	_check(menu.find_child("AudioPage", true, false) == null and menu.find_child("更多设置", true, false) == null, "no intermediate audio or more-settings page")
	_check(panel.get_node("Background") is TextureRect, "actual artwork replaces old grey background")
	_check(panel.find_child("MenuRaysQuality", true, false) == null, "no rays selector")
	var position := AudioManager.get_music_position()
	await _wait()
	_check(AudioManager.get_music_position() > position + 0.05, "title music continues")
	for key: String in ["Master", "Music", "SFX", "UI"]:
		var slider: HSlider = panel.get_node("%"+key+"Slider")
		await _drag(slider)
		_check(slider.value > 0.6 and slider.value < 0.8, key+" slider responds to actual drag")
	await _capture("title-settings")
	await _click(panel.get_node("%BackButton"))
	_check(not get_tree().paused and not menu.get_node("%Overlay").visible, "Back returns directly to title")
	var saved_volume := SettingsManager.music_volume
	SettingsManager.load_settings()
	_check(is_equal_approx(saved_volume, SettingsManager.music_volume), "slider value persists on return")
	await _click(title.get_node("%SettingsButton"))
	await _escape()
	_check(not menu.get_node("%Overlay").visible, "title settings Esc returns directly")
	await _escape()
	await _click(menu.get("_settings_button"))
	_check(get_tree().paused and panel.visible, "pause opens the same slider panel")
	await _capture("pause-settings")
	SettingsManager.set_fullscreen(true)
	await _wait()
	panel.open()
	await _click(panel.get_node("%FullscreenCheck"))
	_check(not SettingsManager.fullscreen, "artwork settings can exit fullscreen")
	await _escape()
	_check(get_tree().paused and menu.get_node("%MainPage").visible, "settings Esc returns to pause")
	await _escape()
	_check(not get_tree().paused, "second Esc resumes")
	await _click(title.get_node("%SettingsButton"))
	await _click(panel.get_node("%ResetButton"))
	_check(SettingsManager.menu_rays_quality == 1 and is_equal_approx(SettingsManager.music_volume, SettingsManager.DEFAULT_MUSIC_VOLUME), "reset retains low lighting and resets volumes")
	await _click(panel.get_node("%BackButton"))
	print("UNIFIED_SETTINGS_DONE failures=", failures)
	get_tree().quit(failures)

# 原生鼠标按住并移动滑块，不通过直接赋值代替交互。
func _drag(slider: HSlider) -> void:
	var rect := slider.get_global_rect()
	var event := InputEventMouseButton.new()
	event.position = get_viewport().get_final_transform() * (rect.position + Vector2(rect.size.x * 0.3, rect.size.y * 0.5))
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var move := InputEventMouseMotion.new()
	move.position = get_viewport().get_final_transform() * (rect.position + Vector2(rect.size.x * 0.7, rect.size.y * 0.5))
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(move)
	Input.flush_buffered_events()
	await get_tree().process_frame
	event = InputEventMouseButton.new()
	event.position = move.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _wait()
func _click(button: BaseButton) -> void:
	var point := get_viewport().get_final_transform() * button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	Input.parse_input_event(move)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame
	await _wait()
func _escape() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame
func _wait() -> void:
	await get_tree().create_timer(0.2).timeout
func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("D:/src/playtest-20261020/unified-"+label+".png")
func _check(ok: bool, message: String) -> void:
	print("UNIFIED_SETTINGS ", "PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
