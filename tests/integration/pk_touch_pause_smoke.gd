extends Node
const GAME: PackedScene=preload("res://scenes/sandbox/sandbox_plan_b.tscn")
var failures := 0
var shots := 0
var publishes := 0
var pause_requests := 0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene=null
	get_window().size=Vector2i(1280,720)
	get_tree().create_timer(40.0).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()

# 正式PK页分别使用鼠标与无鼠标模拟的原生触屏输入，验证同一暂停菜单。
func _run() -> void:
	SceneRouter.game_scene_override=GAME
	SaveManager.new_game()
	SaveManager.confirm_opening_identity("触屏验收",IdentityOptions.CARDS[0],"测试团",IdentityConfirmationState.new())
	_check(SceneRouter.goto_game()==OK,"formal PK route")
	while SceneRouter.is_transitioning(): await get_tree().process_frame
	await _wait()
	var scene := get_tree().current_scene
	var hud: Control=scene.get_plan_b_battle_ui()
	var button: Button=hud.find_child("PauseButton",true,false)
	var menu: CanvasLayer=scene.get_node("%PauseMenu")
	var host: Node=scene.get_plan_b_battle_host()
	var attack: Node=scene.get("_attack_charge_input")
	hud.pause_requested.connect(func(): pause_requests+=1)
	attack.shot_snapshot_created.connect(func(_snapshot): shots+=1)
	hud.publish_requested.connect(func(_slot,_word,_position): publishes+=1)
	var board: Rect2=hud.get_board_world_bounds()
	_check(button!=null and button.is_visible_in_tree(),"PK has visible native pause button")
	_check(board.position==Vector2(448,72) and board.size==Vector2(1024,828),"original board geometry unchanged")
	_check(not button.get_global_rect().intersects(board),"pause touch area does not overlap board")
	var pixel_size := button.size*Vector2(get_window().size)/get_viewport().get_visible_rect().size
	_check(pixel_size.x>=48.0 and pixel_size.y>=48.0,"720p touch target at least 48 pixels")
	await _capture("pk-pause-720")
	await _click(button)
	_check(get_tree().paused and menu.get_node("%Overlay").visible,"mouse button opens original pause menu")
	var pk: float=host.get_pk()
	var position := AudioManager.get_music_position()
	await _wait()
	_check(host.get_pk()==pk and absf(AudioManager.get_music_position()-position)<0.08,"PK and BGM freeze while paused")
	await _click(menu.get("_settings_button"))
	_check(menu.get_node("%SettingsPanel").visible,"settings reachable from PK button")
	await _escape()
	await _click(menu.get("_resume_button"))
	_check(not get_tree().paused,"original continue resumes")
	var old_emulation := Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch=false
	await _touch(button)
	_check(get_tree().paused and menu.get_node("%Overlay").visible,"raw ScreenTouch opens pause with mouse emulation disabled")
	_check(not attack.is_charge_held() and shots==0 and publishes==0,"pause input does not charge shoot or publish")
	await _capture("pk-touch-paused")
	await _click(menu.get("_resume_button"))
	Input.emulate_mouse_from_touch=old_emulation
	await _escape()
	_check(get_tree().paused,"Esc still opens same menu")
	await _escape()
	_check(not get_tree().paused,"Esc still resumes")
	get_window().size=Vector2i(2400,1080)
	await _wait()
	print("PK_TOUCH_PAUSE_WIDE rect=",button.get_global_rect()," board=",hud.get_board_world_bounds()," window=",get_window().size," viewport=",get_viewport().get_visible_rect()," emulation=",Input.emulate_mouse_from_touch)
	_check(get_viewport().get_visible_rect().encloses(button.get_global_rect()),"20:9 button stays inside viewport")
	_check(not button.get_global_rect().intersects(hud.get_board_world_bounds()),"20:9 button stays outside board")
	await _capture("pk-pause-20x9")
	await _touch(button)
	print("PK_TOUCH_PAUSE_WIDE requests=",pause_requests," tree_paused=",get_tree().paused)
	_check(get_tree().paused,"20:9 touch opens menu")
	await _click(menu.get("_resume_button"))
	_check(not get_tree().paused and shots==0 and publishes==0,"20:9 resume has no leaked combat input")
	SceneRouter.game_scene_override=null
	print("PK_TOUCH_PAUSE_DONE failures=",failures)
	get_tree().quit(failures)

func _touch(button: Button) -> void:
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index=0
		event.position=_point(button)
		event.pressed=pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame
	await _wait()
func _point(button: BaseButton) -> Vector2:
	# 宽屏黑边不是内容缩放，使用最终视口变换，避免用窗口宽比把触点移到右侧立绘。
	return get_viewport().get_final_transform()*button.get_global_rect().get_center()
func _click(button: BaseButton) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position=_point(button)
	Input.parse_input_event(motion)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=_point(button)
		event.pressed=pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame
	await _wait()
func _escape() -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=KEY_ESCAPE
		event.pressed=pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame
func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("D:/src/playtest-20261020/"+label+".png")
func _wait() -> void:
	await get_tree().create_timer(0.2).timeout
func _check(ok: bool, message: String) -> void:
	print("PK_TOUCH_PAUSE ","PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
