extends Node
var failures: int = 0
var emphasis_finished: bool = false
const OUT = "D:/src/playtest-20261020/epilogue"
func _ready() -> void:
	get_tree().current_scene = null
	get_window().size = Vector2i(1920,1080)
	get_window().title = "Oracle epilogue and credits verification"
	DirAccess.make_dir_recursive_absolute(OUT)
	get_tree().create_timer(65.0).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()
# 完整使用正式Sandbox结束入口、真实P5/P6与自动计时，覆盖全局Esc和原结局快照交付。
func _run() -> void:
	SaveManager.new_game()
	SaveManager.data.identity_id = IdentityOptions.CARDS[0].identity_id
	SaveManager.data.tendency_state.initialize_from_identity_option(IdentityOptions.CARDS[0])
	_check(SceneRouter.goto_game() == OK,"game route accepted")
	await _settle()
	var scene: Node = get_tree().current_scene
	scene.get_battle_attempt_flow().stop()
	var music: EndingMusicPresenter = scene.get("_ending_music")
	music.start()
	var emphasis := DivineDescentEmphasis.new()
	scene.add_child(emphasis)
	emphasis.finished.connect(func(): emphasis_finished = true)
	var config: Resource = load("res://data/divine_descent/divine_descent_decay_config.tres")
	_check(config.final_emphasis_duration_seconds == 7.0,"formal emphasis duration is seven seconds")
	var start := Time.get_ticks_msec()
	_check(emphasis.play_for_total_duration("祂要是全知，知道鼠偷吃了吗？",config.final_emphasis_duration_seconds),"emphasis starts")
	await get_tree().create_timer(1.7).timeout
	_check(not emphasis_finished,"oracle stays visible beyond old duration")
	await _capture("oracle_1920")
	await _escape()
	_check(get_tree().paused,"Esc pauses oracle presentation")
	await _capture("oracle_paused_1920")
	await get_tree().create_timer(0.5).timeout
	_check(not emphasis_finished,"pause does not finish oracle")
	await _escape()
	while not emphasis_finished: await get_tree().process_frame
	_check(Time.get_ticks_msec()-start >= 7400,"full emphasis time plus pause preserved")
	var descent := DivineDescentSession.new()
	_check(descent.enter(SaveManager.data),"freeze final state")
	var ending := EndingSession.new()
	_check(ending.receive_final_state(descent,load("res://data/level_configuration/level_catalog.tres")),"receive ending once")
	var display: Dictionary = ending.get_display_data()
	var position := AudioManager.get_music_position()
	scene.call("_finish_divine_descent",ending)
	await _settle()
	var movie: ComicPlayer = get_tree().current_scene as ComicPlayer
	_check(movie != null,"real completion routes to epilogue")
	if movie == null:
		get_tree().quit(1)
		return
	_check(movie.get("_sequence").frames.size() == 6 and SceneRouter.comic_kind == &"epilogue","only original P5/P6 six panels")
	_check(AudioManager.get_music_event_id() == EndingMusicPresenter.EVENT and AudioManager.get_music_position() >= position-0.1,"ending music keeps event and position")
	await get_tree().create_timer(0.7).timeout
	await _capture("p5_1920")
	await _escape()
	var number: int = movie.get_playback_control().get("_current_panel_number")
	await get_tree().create_timer(0.4).timeout
	_check(get_tree().paused and movie.get_playback_control().get("_current_panel_number") == number,"Esc freezes epilogue timer")
	await _escape()
	var captured_p6 := false
	while is_instance_valid(movie) and not SceneRouter.is_transitioning():
		if movie.get_playback_control().get("_current_panel_number") >= 4 and not captured_p6:
			await get_tree().create_timer(0.6).timeout
			await _capture("p6_1920")
			captured_p6 = true
		await get_tree().process_frame
	await _settle()
	var page: EndingPage = get_tree().current_scene as EndingPage
	_check(page != null,"automatic epilogue completion reaches credits")
	_check(page.get("_display_data") == display,"same ending snapshot delivered")
	_check(AudioManager.get_music_event_id() == EndingMusicPresenter.EVENT,"credits keep Tendoh")
	_check(page.find_child("Credits",true,false) != null,"credits contain production group and sources")
	await _capture("credits_1920")
	get_window().size = Vector2i(1280,720)
	await _capture("credits_1280")
	await _escape()
	_check(get_tree().paused,"Esc works on credits")
	await _escape()
	_check(SceneRouter.goto_saved_ending(display) == OK,"saved ending route accepted")
	await _settle()
	_check(get_tree().current_scene is EndingPage,"saved ending opens credits without replaying story")
	var button: Button = get_tree().current_scene.find_child("CreditsMainMenu",true,false)
	button.pressed.emit()
	await _settle()
	_check(get_tree().current_scene.scene_file_path == SceneRouter.MAIN_MENU_SCENE_PATH,"credits can return to title")
	print("EPILOGUE_DONE failures=",failures)
	get_tree().quit(failures)
func _settle() -> void:
	while SceneRouter.is_transitioning(): await get_tree().process_frame
	await get_tree().process_frame
func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+"/"+name+".png")
func _escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
func _check(ok: bool,message: String) -> void:
	print("EPILOGUE ","PASS " if ok else "FAIL ",message)
	if not ok:
		failures += 1
		push_error(message)
