extends Node
# 隔离用户目录的真实GUI回归；末关Rest夹具之后使用正式神降临、P5/P6与原时长片尾。
const GAME: PackedScene = preload("res://scenes/sandbox/sandbox_plan_b.tscn")
const OUT = "D:/src/playtest-20261020/end02"
var failures: int = 0
var stages: Array[StringName] = []
var stage_times: Dictionary = {}
var page: EndingPage
var frames: int = 0
var title_frames: int = 0
var captured: Dictionary = {}
var _music_capture: AudioEffectCapture
var _handoff_started: int = 0
var _handoff_position: float = 0.0
var _capturing_handoff: bool = false
var _audio_frames: int = 0
var _silent_frames: int = 0
var _longest_silence: int = 0
var _handoff_verified: bool = false

func _ready() -> void:
	# 观察器在路由暂停整树时仍采样；被测正式页面继续使用原暂停模式。
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	SceneRouter.game_scene_override = GAME
	get_window().size = Vector2i(1280,720)
	get_window().title = "END-02 actual ending sequence verification"
	DirAccess.make_dir_recursive_absolute(OUT)
	_music_capture = AudioEffectCapture.new()
	_music_capture.buffer_length = 2.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"Music"),_music_capture)
	SceneRouter.transition_started.connect(_on_transition_started)
	SceneRouter.transition_finished.connect(_on_transition_finished)
	get_tree().create_timer(180.0).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()

func _run() -> void:
	if "--pending" in OS.get_cmdline_user_args():
		_check(not SettingsManager.ending_replay_unlocked,"interrupted process stays locked")
		_check(SaveManager.load_game()==OK and SaveManager.data.ending_roll_pending,"interrupted run marker recovered")
		_check(SceneRouter.goto_main_menu()==OK,"interrupted return to title")
		await _settle()
		get_tree().current_scene.get_node("%ContinueButton").pressed.emit()
		await _settle()
		_check(get_tree().current_scene is ComicPlayer and SceneRouter.comic_kind==&"epilogue","Continue resumes original ending rather than static credits")
		_check(SceneRouter.is_ending_performance_active() and not SettingsManager.ending_replay_unlocked,"resumed flow remains locked before completion")
		_finish("PENDING")
		return
	if "--restart" in OS.get_cmdline_user_args():
		_check(SettingsManager.ending_replay_unlocked,"new process persisted unlock")
		_check(SaveManager.load_game()==OK and not SaveManager.data.ending_roll_pending,"new process completed run")
		_check(SceneRouter.goto_main_menu()==OK,"restart title route")
		await _settle()
		_check(not get_tree().current_scene.get_node("%ReplayEndingButton").disabled,"restart replay available")
		_finish("RESTART")
		return
	_check(not SettingsManager.ending_replay_unlocked,"fresh profile locked")
	_check(SceneRouter.goto_comic(&"ending")==ERR_UNAUTHORIZED,"locked replay rejected by router")
	SaveManager.new_game()
	_check(SceneRouter.goto_saved_ending({"scripture":{"rows":[],"is_empty":true}})==OK,"static entry")
	await _settle()
	var static_page := get_tree().current_scene as EndingPage
	static_page.start_credits_performance()
	_check(static_page.get_credits_stage()==&"static" and SceneRouter.finish_ending_credits(static_page)==ERR_UNCONFIGURED,"static credits cannot unlock")
	var source_text := ""
	for label: Node in static_page.get("_special_group").get_children(): source_text += label.text
	for source in ["煉獄小僧","FELT LOVE","Kenney","ObsydianX","Cassie-OrbitGames","JaggedStone","CC0","https://opengameart.org/content/magic-spell-sfx"]:
		_check(source in source_text,"source retained: "+source)
	static_page.find_child("CreditsMainMenu",true,false).pressed.emit()
	await _settle()
	_check(not SettingsManager.ending_replay_unlocked and get_tree().current_scene.get_node("%ReplayEndingButton").disabled,"ordinary return stays locked")
	SaveManager.new_game()
	_check(SaveManager.confirm_opening_identity("片尾测试",IdentityOptions.CARDS[0],"测试团",IdentityConfirmationState.new())==OK,"identity fixture")
	var catalog: LevelCatalog = load("res://data/level_configuration/level_catalog.tres")
	SaveManager.data.next_normal_level_order = 4
	for index in range(3): SaveManager.data.completed_normal_level_ids.append(catalog.profiles[index].level_id)
	for speech: LevelSpeech in catalog.profiles[0].get_normal_speech_pool():
		if speech.tendency_id in ["orthodox","heretical","absurd"]:
			SaveManager.data.committed_normal_hit_history.append({"original_sentence_id":speech.original_sentence_id,"original_sentence_text":speech.text,"tendency":speech.tendency_id,"hit_count":1,"first_committed_hit_order":1})
			break
	_check(SceneRouter.goto_game()==OK,"formal game route")
	await _settle()
	var game: Node = get_tree().current_scene
	var rest := RestSession.new()
	_check(rest.open_result({"level_id":catalog.profiles[3].level_id,"result_kind":"pk_win_unbroken"}),"last rest fixture")
	game.get_contradiction_oracle_flow().rest_ready.emit(rest)
	await get_tree().process_frame
	game.get_rest_result_view().get_node("%ContinueButton").pressed.emit()
	await _until(func(): return game.get_divine_descent_flow()!=null and game.get_divine_descent_flow().get_spread()!=null and game.get_divine_descent_flow().get_spread().is_converging(),"real convergence",65.0)
	var emphasis: DivineDescentEmphasis = game.get_divine_descent_flow().get_spread().get("_full_screen_emphasis")
	_check(AudioManager.get_music_event_id()!=EndingMusicPresenter.EVENT,"ending BGM waits until oracle finishes")
	await get_tree().create_timer(1.0).timeout
	await _capture("oracle")
	await _escape()
	_check(get_tree().paused,"oracle Esc pause")
	await get_tree().create_timer(0.4).timeout
	await _escape()
	await get_tree().create_timer(5.4).timeout
	_check(AudioManager.get_music_event_id()!=EndingMusicPresenter.EVENT,"oracle full reading hold precedes ending BGM")
	for index in range(12):
		if is_instance_valid(emphasis):
			_check(emphasis.get("_overlay").visible and emphasis.get("_overlay").modulate.a==1.0,"oracle exit opaque black "+str(index))
		await get_tree().create_timer(0.035).timeout
	await _capture("oracle_exit_black")
	await _until(func(): return get_tree().current_scene is ComicPlayer and not SceneRouter.is_transitioning(),"real P5/P6")
	var movie := get_tree().current_scene as ComicPlayer
	_check(SceneRouter.comic_kind==&"epilogue" and movie.get("_sequence").frames.size()==6,"six original panels reused")
	_check(AudioManager.get_music_event_id()==EndingMusicPresenter.EVENT,"ending BGM starts with movie handoff")
	movie.get_playback_control().panel_display_requested.connect(func(panel_number: int): print("END02_PANEL ",panel_number," paused=",get_tree().paused))
	_check(not SettingsManager.ending_replay_unlocked and SaveManager.data.ending_roll_pending,"movie locked with pending run")
	var disk: SaveData = ResourceLoader.load(SaveManager.SAVE_PATH,"",ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	_check(disk.ending_roll_pending,"pending saved on disk")
	var number: int = movie.get_playback_control().get("_current_panel_number")
	movie.advance()
	_check(movie.get_playback_control().get("_current_panel_number")==number and SceneRouter.goto_main_menu()==ERR_BUSY,"normal movie cannot skip")
	await _capture("p5")
	await _until(func(): return get_tree().current_scene is EndingPage,"movie auto completion",40.0)
	page = get_tree().current_scene as EndingPage
	if page == null:
		return
	page.credits_stage_changed.connect(_on_stage)
	await _settle()
	await get_tree().create_timer(1.8).timeout
	await _escape()
	var tween: Tween = page.get("_credits_tween")
	var elapsed := tween.get_total_elapsed_time()
	await get_tree().create_timer(0.5).timeout
	_check(get_tree().paused and absf(tween.get_total_elapsed_time()-elapsed)<0.02,"credits timeline pauses")
	var pause := page.find_child("PauseMenu",true,false)
	_check(pause.get_node("%MainMenuButton").disabled,"pause return disabled")
	pause.get_node("%MainMenuButton").pressed.emit()
	_check(get_tree().paused and get_tree().current_scene==page,"return callback cannot skip")
	await _escape()
	await _until(func(): return get_tree().current_scene!=null and get_tree().current_scene.scene_file_path==SceneRouter.MAIN_MENU_SCENE_PATH and not SceneRouter.is_transitioning(),"full credits and title natural completion",65.0)
	if get_tree().current_scene==null or get_tree().current_scene.scene_file_path!=SceneRouter.MAIN_MENU_SCENE_PATH:
		return
	_check(stages==[&"production_title",&"production_roster",&"production_hold",&"special_thanks",&"special_hold",&"complete"],"strict stage order without Thank you "+str(stages))
	_check(frames>1000 and title_frames>10 and captured.has("roster_mid_fade"),"continuous GUI monitoring and whole roster fade")
	_check(stage_times[&"special_thanks"]-stage_times[&"production_hold"]>=8500,"production reading hold")
	_check(stage_times[&"complete"]-stage_times[&"special_hold"]>=12500 and stage_times[&"complete"]-stage_times[&"special_hold"]<14000,"special reading hold is twelve seconds")
	_check(_handoff_verified,"movie to credits audio continuity verified")
	_check(SettingsManager.ending_replay_unlocked and not SaveManager.data.ending_roll_pending,"unlock after title reveal")
	_check(not get_tree().current_scene.get_node("%ReplayEndingButton").disabled,"replay enabled")
	await _capture("title_ready")
	SaveManager.new_game()
	_check(SettingsManager.ending_replay_unlocked,"new run retains unlock")
	_check(SaveManager.load_game()==OK and not SaveManager.data.ending_roll_pending,"run completion persisted")
	get_tree().current_scene.get_node("%ReplayToggleButton").pressed.emit()
	_check(get_tree().current_scene.get_node("%ReplayActions").visible,"menu interaction restored")
	get_tree().current_scene.get_node("%ReplayEndingButton").pressed.emit()
	await _settle()
	_check(get_tree().current_scene is ComicPlayer and SceneRouter.comic_kind==&"ending","unlocked replay works")
	_finish("GUI")

func _process(_delta: float) -> void:
	if _capturing_handoff:
		_read_music_samples()
	if is_instance_valid(page) and get_tree().current_scene==page and page.get_credits_stage()!=&"waiting":
		frames+=1
		var stage := page.get_credits_stage()
		var production: Control = page.get("_production_group")
		var special: Control = page.get("_special_group")
		if production.visible and special.visible: _check(false,"overlap")
		if SettingsManager.ending_replay_unlocked: _check(false,"premature credits unlock")
		if stage==&"production_title" and not captured.has("title_only"):
			var heading: Control = page.get("_production_title")
			if heading.modulate.a>0.3:
				captured["title_only"]=true
				_check(page.get("_production_roster").modulate.a==0.0,"title appears independently before roster")
				_capture.call_deferred("production_title_only")
		if stage==&"production_roster":
			var roster: Control = page.get("_production_roster")
			if roster.modulate.a>0.2 and roster.modulate.a<0.8 and not captured.has("roster_mid_fade"):
				captured["roster_mid_fade"]=true
				for child: Control in roster.get_children(): _check(child.modulate.a==1.0,"roster children share parent opacity")
				_capture.call_deferred("roster_mid_fade")
		if stage in [&"production_hold",&"special_hold"] and not captured.has(stage):
			captured[stage]=true
			if stage==&"special_hold":
				_check(special.get_global_rect().end.y<=page.size.y-20,"all special thanks fit screen")
				_check(page.get_node("Background").color==Color.BLACK and page.find_child("ThankYou",true,false)==null,"pure black credits and no Thank you node")
			if stage==&"production_hold":
				var roster_text := ""
				for row: Node in page.get("_production_roster").get_children(): roster_text += row.text
				_check(not "昂昂小火车番茄牛腩akai" in roster_text and "程序：昂昂、Akai" in roster_text,"only role roster; concatenated names removed")
				page.start_credits_performance()
				_check(page.get_credits_stage()==stage and SceneRouter.finish_ending_credits(page)==ERR_UNCONFIGURED,"duplicate start and early finish rejected")
			_capture.call_deferred(str(stage))
	if get_tree().current_scene!=null and get_tree().current_scene.scene_file_path==SceneRouter.MAIN_MENU_SCENE_PATH and SceneRouter.get("_completion_stage")==&"title":
		title_frames+=1
		if SettingsManager.ending_replay_unlocked: _check(false,"premature title unlock")
		var cover: Control = SceneRouter.get("_loading_screen")
		if cover.modulate.a>0.35 and cover.modulate.a<0.65 and not captured.has("title_mid"):
			captured["title_mid"]=true
			_check(get_tree().paused and SceneRouter.is_transitioning(),"whole menu input locked until reveal")
			var menu := get_tree().current_scene
			menu.get_node("%StartButton").grab_focus()
			var enter := InputEventKey.new()
			enter.keycode=KEY_ENTER
			enter.pressed=true
			Input.parse_input_event(enter)
			Input.flush_buffered_events()
			_check(get_tree().current_scene==menu and SceneRouter.is_transitioning(),"native Enter cannot operate title during fade")
			_capture.call_deferred("title_mid_fade")

func _on_stage(stage: StringName) -> void:
	stages.append(stage)
	stage_times[stage]=Time.get_ticks_msec()
	print("END02_STAGE ",stage," ms=",Time.get_ticks_msec())

# 真实Music总线采样与播放时钟同时覆盖慢淡出、全黑停留及揭幕，避免仅查事件ID。
func _on_transition_started(path: String) -> void:
	if path==SceneRouter.ENDING_SCENE_PATH and get_tree().current_scene is ComicPlayer and SceneRouter.is_ending_performance_active():
		_handoff_started=Time.get_ticks_msec()
		_handoff_position=AudioManager.get_music_position()
		_music_capture.clear_buffer()
		_capturing_handoff=true
		_audio_frames=0
		_silent_frames=0
		_longest_silence=0

func _on_transition_finished(path: String) -> void:
	if not _capturing_handoff or path!=SceneRouter.ENDING_SCENE_PATH:
		return
	_read_music_samples()
	_capturing_handoff=false
	var elapsed := float(Time.get_ticks_msec()-_handoff_started)/1000.0
	var advanced := AudioManager.get_music_position()-_handoff_position
	var silent_seconds := float(_longest_silence)/AudioServer.get_mix_rate()
	_check(elapsed>=2.0,"movie fades 0.9s plus black hold 0.6s and reveal")
	_check(advanced>=elapsed-0.15 and advanced<elapsed+0.15,"same music clock continuous through tree-paused handoff")
	_check(_audio_frames>20000 and silent_seconds<0.1,"actual Music samples have no handoff gap over 100ms")
	print("END02_AUDIO elapsed=",elapsed," advanced=",advanced," frames=",_audio_frames," max_silence=",silent_seconds)
	_handoff_verified=true

func _read_music_samples() -> void:
	var available := _music_capture.get_frames_available()
	if available==0:
		return
	var samples := _music_capture.get_buffer(available)
	for sample: Vector2 in samples:
		_audio_frames+=1
		_silent_frames=_silent_frames+1 if absf(sample.x)+absf(sample.y)<0.00001 else 0
		_longest_silence=maxi(_longest_silence,_silent_frames)

func _until(predicate: Callable, message: String, timeout: float=35.0) -> void:
	var start := Time.get_ticks_msec()
	while not predicate.call() and Time.get_ticks_msec()-start<int(timeout*1000.0): await get_tree().process_frame
	_check(predicate.call(),message)
	if not predicate.call():
		var scene := get_tree().current_scene
		print("END02_TIMEOUT scene=",scene," paused=",get_tree().paused," route=",SceneRouter.is_transitioning())
		if scene is ComicPlayer:
			print("END02_TIMEOUT comicpaused=",scene.get("_paused")," controlpaused=",scene.get_playback_control().get("_is_paused")," timer=",scene.get_playback_control().get("_timer").time_left)
		get_tree().quit(1)

func _settle() -> void:
	while SceneRouter.is_transitioning(): await get_tree().process_frame
	await get_tree().process_frame

func _escape() -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=KEY_ESCAPE
		event.pressed=pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+"/"+name+".png")

func _check(ok: bool, message: String) -> void:
	print("END02 ","PASS " if ok else "FAIL ",message)
	if not ok:
		failures+=1
		push_error(message)

func _finish(kind: String) -> void:
	print("END02_",kind,"_DONE failures=",failures," frames=",frames," title_frames=",title_frames)
	get_tree().quit(failures)
