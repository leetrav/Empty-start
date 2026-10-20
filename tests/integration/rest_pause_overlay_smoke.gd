extends Node
const GAME: PackedScene=preload("res://scenes/sandbox/sandbox_plan_b.tscn")
var failures := 0
var menu: CanvasLayer

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene=null
	get_window().size=Vector2i(1280,720)
	get_tree().create_timer(45.0).timeout.connect(func():
		SettingsManager.set_fullscreen(false)
		get_tree().quit(2))
	_run.call_deferred()

# 正式Sandbox结算组合层，检查原结算与两个历史子页真实鼠标能点击暂停菜单。
func _run() -> void:
	SceneRouter.game_scene_override=GAME
	SaveManager.new_game()
	SaveManager.confirm_opening_identity("暂停验收",IdentityOptions.CARDS[0],"测试团",IdentityConfirmationState.new())
	_check(SceneRouter.goto_game()==OK,"formal battle route")
	await _settle()
	var game := get_tree().current_scene
	var result: RestResultView=game.get_rest_result_view()
	menu=game.get_node("%PauseMenu")
	var catalog: LevelCatalog=load("res://data/level_configuration/level_catalog.tres")
	var session := RestSession.new()
	_check(session.open_result({"level_id":catalog.profiles[0].level_id,"result_kind":"breakthrough_oracle_complete"}),"rest display context")
	game.get_contradiction_oracle_flow().rest_ready.emit(session)
	await _wait()
	_check(result.get_node("%Overlay").visible,"actual result view shown")
	_check(menu.layer>result.layer and menu.layer<SceneRouter.get("_loading_layer").layer,"pause above result and below loading")
	var original := session.get_result_snapshot()
	await _exercise("result")
	await _click(result.get_node("%ScriptureHistoryButton"))
	_check(result.get_node("%ScriptureHistoryView").visible,"native click opens scripture history")
	await _exercise("scripture")
	await _click(result.get_node("%ScriptureHistoryView").get_node("%BackButton"))
	await _click(result.get_node("%LoserCardHistoryButton"))
	_check(result.get_node("%LoserCardHistoryView").visible,"native click opens loser history")
	await _exercise("loser")
	await _click(result.get_node("%LoserCardHistoryView").get_node("%BackButton"))
	SettingsManager.set_fullscreen(true)
	await _wait()
	await _escape()
	await _click(menu.get("_settings_button"))
	var settings: Control=menu.get_node("%SettingsPanel")
	_check(settings.visible,"fullscreen result pause settings reachable by mouse")
	await _click(settings.get_node("%FullscreenCheck"))
	_check(not SettingsManager.fullscreen and DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED,"settings click exits fullscreen")
	await _escape()
	_check(get_tree().paused and not settings.visible,"Esc closes settings and retains pause")
	_check(session.get_result_snapshot()==original and SaveManager.data.completed_normal_level_ids.is_empty(),"pause/history does not advance or mutate result")
	await _click(menu.get("_main_menu_button"))
	await _settle()
	_check(not get_tree().paused and get_tree().current_scene.scene_file_path==SceneRouter.MAIN_MENU_SCENE_PATH,"native pause return goes to usable title")
	SceneRouter.game_scene_override=null
	print("REST_PAUSE_DONE failures=",failures)
	get_tree().quit(failures)

func _exercise(label: String) -> void:
	var previous := get_viewport().gui_get_focus_owner()
	await _escape()
	_check(get_tree().paused and menu.get_node("%Overlay").visible,label+" Esc opens menu")
	var before := AudioManager.get_music_position()
	await _wait()
	_check(absf(AudioManager.get_music_position()-before)<0.1,label+" music paused")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("D:/src/playtest-20261020/rest-pause-"+label+".png")
	await _click(menu.get("_settings_button"))
	_check(menu.get_node("%SettingsPanel").visible,label+" settings receives actual mouse click")
	await _escape()
	_check(get_tree().paused and not menu.get_node("%SettingsPanel").visible,label+" settings Esc returns to pause")
	await _click(menu.get("_resume_button"))
	_check(not get_tree().paused and not menu.get_node("%Overlay").visible,label+" native continue resumes")
	_check(get_viewport().gui_get_focus_owner()==previous,label+" prior focus restored")

func _settle() -> void:
	while SceneRouter.is_transitioning(): await get_tree().process_frame
	await get_tree().process_frame
func _wait() -> void:
	await get_tree().create_timer(0.2).timeout
func _escape() -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=KEY_ESCAPE
		event.physical_keycode=KEY_ESCAPE
		event.pressed=pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame
func _click(button: BaseButton) -> void:
	var point := get_viewport().get_final_transform()*button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position=point
	Input.parse_input_event(move)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=point
		event.pressed=pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame
	await _wait()
func _check(ok: bool, message: String) -> void:
	print("REST_PAUSE ","PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
