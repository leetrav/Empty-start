extends Node
# 两个独立用户目录分别验证初始状态与真实END-02完成存档；不用直接赋true冒充通关。
const OUT = "D:/src/playtest-20261020/story01"
var failures: int = 0
var unlocked: bool = false
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene=null
	get_window().size=Vector2i(1280,720)
	get_window().title="STORY-01 actual replay menu verification"
	DirAccess.make_dir_recursive_absolute(OUT)
	get_tree().create_timer(60.0).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()

func _run() -> void:
	unlocked=not "--locked" in OS.get_cmdline_user_args()
	_check(SettingsManager.ending_replay_unlocked==unlocked,"restart reads expected persisted unlock")
	_check(SceneRouter.goto_main_menu()==OK,"title route")
	await _settle()
	var menu := get_tree().current_scene
	var toggle: Button=menu.get_node("%ReplayToggleButton")
	_check(toggle.caption=="剧情回放" and not toggle.disabled,"initial entry named and usable")
	await _click(toggle)
	_check(menu.get_node("%ReplayActions").visible and not menu.get_node("%MenuActions").visible,"native click opens independent submenu")
	_check(menu.find_child("ReplayFullOpeningButton",true,false)==null,"no duplicate opening entry")
	var back: Button=menu.get_node("%ReplayBackButton")
	_check(back.position==toggle.position and back.size==toggle.size and back.text_size==toggle.text_size,"return at original lower-left position and size")
	var visible: Array[String]=[]
	for child: Node in menu.get_node("%ReplayActions").get_children():
		if child is Button and child.visible: visible.append(child.caption)
	var expected: Array=["开场回放","结局回放","返回菜单"] if unlocked else ["开场回放","返回菜单"]
	_check(visible==expected,"exact visible buttons: "+str(visible))
	_check(menu.get_node("%ReplayEndingButton").visible==unlocked,"locked ending fully hidden, no placeholder")
	await _capture("unlocked_1280" if unlocked else "locked_1280")
	get_window().size=Vector2i(1920,1080)
	await get_tree().process_frame
	await _capture("unlocked_1920" if unlocked else "locked_1920")
	get_window().size=Vector2i(1280,720)
	await get_tree().process_frame
	await _click(back)
	_check(menu.get_node("%MenuActions").visible and not menu.get_node("%ReplayActions").visible,"native return restores same original menu")
	await _click(toggle)
	await _click(menu.get_node("%ReplayOpeningButton"))
	await _settle()
	var comic := get_tree().current_scene as ComicPlayer
	_check(comic!=null and SceneRouter.comic_kind==&"opening" and comic.get_playback_control().panel_count==13,"opening replay uses existing first four acts")
	_finish_movie(comic)
	await _settle()
	_check(get_tree().current_scene.scene_file_path==SceneRouter.MAIN_MENU_SCENE_PATH,"opening replay returns to title")
	if unlocked:
		menu=get_tree().current_scene
		await _click(menu.get_node("%ReplayToggleButton"))
		await _click(menu.get_node("%ReplayEndingButton"))
		await _settle()
		comic=get_tree().current_scene as ComicPlayer
		_check(comic!=null and SceneRouter.comic_kind==&"ending" and comic.get_playback_control().panel_count==6,"ending replay uses existing last two acts")
		_finish_movie(comic)
		await _settle()
		_check(get_tree().current_scene.scene_file_path==SceneRouter.MAIN_MENU_SCENE_PATH,"ending replay returns normally")
	else:
		_check(SceneRouter.goto_comic(&"ending")==ERR_UNAUTHORIZED,"hidden ending also rejected by router")
	_check(SettingsManager.ending_replay_unlocked==unlocked,"replays do not fabricate or clear completion")
	print("STORY01_DONE failures=",failures," unlocked=",unlocked)
	get_tree().quit(failures)

func _finish_movie(comic: ComicPlayer) -> void:
	# 既有回放保留快进，正常通关epilogue仍由END-02覆盖不可跳过。
	for index in range(45):
		if SceneRouter.is_transitioning(): break
		comic.advance()

func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	# Input.parse_input_event模拟窗口输入，需将逻辑画布坐标转换成实际窗口像素。
	point *= Vector2(get_window().size)/get_viewport().get_visible_rect().size
	var motion := InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await get_tree().process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame

func _settle() -> void:
	while SceneRouter.is_transitioning(): await get_tree().process_frame
	await get_tree().process_frame

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+"/"+name+".png")

func _check(ok: bool,message: String) -> void:
	print("STORY01 ","PASS " if ok else "FAIL ",message)
	if not ok:
		failures+=1
		push_error(message)
