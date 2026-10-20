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
	SettingsManager.save_settings()
	var config := ConfigFile.new()
	config.load(SettingsManager.SETTINGS_FILE_PATH)
	config.set_value("display", "menu_rays_quality", 2)
	config.save(SettingsManager.SETTINGS_FILE_PATH)
	SettingsManager.load_settings()
	SettingsManager.apply_settings()
	_check(SettingsManager.menu_rays_quality == 1, "old standard config loads as low")
	_check(SceneRouter.goto_main_menu() == OK, "formal title route")
	while SceneRouter.is_transitioning(): await get_tree().process_frame
	await _wait()
	var title := get_tree().current_scene
	var rays := title.get_node("CoverCanvas/Pend00GodRays")
	_check(rays.mask_viewport.size == Vector2i(480, 270), "actual rays viewport is low 480x270")
	await _click(title.get_node("%SettingsButton"))
	var menu := title.find_child("PauseMenu", true, false)
	_check(menu != null and menu.get_node("%AudioPage").is_visible_in_tree(), "title options opens V2 audio page")
	_check(not menu.get_node("%MainPage").visible and not title.get_node("%MenuActions").visible, "standalone settings blocks title interaction")
	_check(title.find_children("PauseMenu", "CanvasLayer", true, false).size() == 1, "only one shared menu instance")
	var position := AudioManager.get_music_position()
	await _wait()
	_check(AudioManager.get_music_position() > position + 0.05, "title BGM continues in settings")
	await _capture("title-settings")
	var row: HBoxContainer = menu.get_node("%AudioActions").get_child(2)
	await _click(row.get_child(1))
	var volume := SettingsManager.music_volume
	await _click(menu.get("_display_settings_button"))
	var panel: Control = menu.get_node("%SettingsPanel")
	_check(panel.visible and panel.find_child("MenuRaysQuality", true, false) == null, "more settings keeps fullscreen without rays selector")
	_check(is_equal_approx(panel.get_node("%MusicSlider").value, volume), "both settings views share actual volume")
	await _escape()
	await _click(menu.get_node("%AudioActions").get_children().back())
	_check(not get_tree().paused and not menu.get_node("%Overlay").visible, "audio return goes directly to usable title")
	await _click(title.get_node("%SettingsButton"))
	await _escape()
	_check(not get_tree().paused and not menu.get_node("%Overlay").visible, "title settings Esc returns directly to title")
	await _escape()
	_check(menu.get_node("%MainPage").is_visible_in_tree(), "ordinary title Esc still opens global pause")
	await _click(menu.get("_settings_button"))
	await _capture("pause-settings")
	await _escape()
	_check(get_tree().paused and menu.get_node("%MainPage").visible, "pause audio Esc returns to pause menu")
	await _escape()
	SettingsManager.reset_to_defaults()
	_check(SettingsManager.menu_rays_quality == 1 and rays.mask_viewport.size == Vector2i(480,270), "reset retains low rendering")
	print("UNIFIED_SETTINGS_DONE failures=", failures)
	get_tree().quit(failures)

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
