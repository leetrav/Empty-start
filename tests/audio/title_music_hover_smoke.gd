extends Node
var _failures: int = 0
var _hover_events: int = 0
var _shots: String = "D:/src/playtest-20261020/title-evidence"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().title = "Title music and hover verification"
	get_window().size = Vector2i(1280, 720)
	get_tree().current_scene = null
	DirAccess.make_dir_recursive_absolute(_shots)
	_run.call_deferred()
	if not OS.get_cmdline_user_args().has("--title-manual"):
		get_tree().create_timer(30.0).timeout.connect(func(): get_tree().quit(2))

func _settle() -> void:
	while SceneRouter.is_transitioning():
		await get_tree().process_frame
	await get_tree().process_frame

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _gain() -> float:
	var player: AudioStreamPlayer = AudioManager.get("_music_player") as AudioStreamPlayer
	return player.volume_linear if player.playing else 0.0

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots.path_join(label + ".png"))

func _event(event_id: StringName, player: AudioStreamPlayer) -> void:
	if event_id == &"ui_menu_hover":
		_hover_events += 1
		print("TITLE_HOVER_EVENT count=", _hover_events)
		_check(player.bus == &"UI" and player.stream.resource_path.ends_with("drop_003.ogg"), "hover uses bubble on UI bus")

func _run() -> void:
	AudioManager.event_played.connect(_event)
	_check(SceneRouter.goto_comic(&"intro") == OK, "opening route accepted")
	await _settle()
	var comic: ComicPlayer = get_tree().current_scene as ComicPlayer
	_check(comic != null and comic.get_playback_control().panel_count == 13, "opening contains four acts / 13 panels")
	# 测试仅快进到末格，不更改正式分镜时长；末格完成仍走真实收尾路由。
	for index: int in comic.get_playback_control().panel_count - 1:
		comic.get_playback_control().advance_on_click()
	await _wait(1.6)
	await _capture("01_final_act")
	var initial_gain: float = _gain()
	comic._finish(&"completed")
	# 按真实帧等待增益下降，避免冷启动某一长帧让固定140ms采样早于Tween首帧。
	var fade_seen: bool = false
	var fade_deadline: int = Time.get_ticks_msec() + 1000
	while get_tree().current_scene == comic and Time.get_ticks_msec() < fade_deadline:
		if _gain() < initial_gain - 0.001:
			fade_seen = true
			break
		await get_tree().process_frame
	_check(fade_seen and get_tree().current_scene == comic, "street fades while last act is covered")
	await _capture("02_fading_curtain")
	await _wait(0.35)
	_check(AudioManager.get_music_event_id() == &"", "street stops before title starts")
	await _capture("03_full_curtain")
	await _settle()
	var menu: Control = get_tree().current_scene as Control
	_check(menu.scene_file_path == SceneRouter.MAIN_MENU_SCENE_PATH, "title revealed after curtain")
	_check(AudioManager.get_music_event_id() == &"music_title_cafe", "title plays Cafe de Fineday")
	_check(_gain() < 0.04, "title starts from near silence")
	await _wait(1.6)
	_check(_gain() > 0.24, "title reaches -12dB after fade")
	var player: AudioStreamPlayer = AudioManager.get("_music_player") as AudioStreamPlayer
	_check(player.stream is AudioStreamOggVorbis and player.stream.loop, "title loops natively")
	await _capture("04_title_ready")
	var position: float = AudioManager.get_music_position()
	menu._on_settings_button_pressed()
	await _wait(0.12)
	menu.get_node("%SettingsPanel").close()
	print("TITLE_DIAG settings before=", position, " after=", AudioManager.get_music_position(), " event=", AudioManager.get_music_event_id())
	_check(AudioManager.get_music_event_id() == &"music_title_cafe" and AudioManager.get_music_position() >= position - 0.08, "settings do not restart music")
	var button: Button = menu.get_node("%StartButton") as Button
	button.mouse_exited.emit()
	await _wait(0.10)
	var before: int = _hover_events
	button.mouse_entered.emit()
	button.mouse_entered.emit()
	_check(_hover_events == before + 1, "one bubble per entry")
	button.mouse_exited.emit()
	await _wait(0.10)
	button.mouse_entered.emit()
	_check(_hover_events == before + 2, "reenter plays another bubble")
	button.mouse_exited.emit()
	await _wait(0.10)
	var disabled_button: Button = menu.get_node("%ContinueButton") as Button
	disabled_button.disabled = true
	disabled_button.mouse_entered.emit()
	_check(_hover_events == before + 2, "disabled item stays silent")
	menu._on_start_button_pressed()
	await _wait(0.12)
	_check(_gain() < 0.24, "leaving title fades its music")
	await _settle()
	_check(get_tree().current_scene.scene_file_path == SceneRouter.IDENTITY_SETUP_SCENE_PATH and AudioManager.get_music_event_id() == &"", "no title music left on name page")
	print("TITLE_AUDIO_DONE failures=", _failures)
	if OS.get_cmdline_user_args().has("--title-manual"):
		SceneRouter.goto_main_menu()
		await _settle()
		print("TITLE_MANUAL_READY")
		return
	get_tree().quit(_failures)

func _check(ok: bool, label: String) -> void:
	print("TITLE_AUDIO ", "PASS " if ok else "FAIL ", label)
	if not ok:
		_failures += 1
