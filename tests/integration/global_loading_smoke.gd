## 全局路由冒烟：真实生产场景、暂停重开和结局快照通过同一异步入口。
extends Node
var _failures: int = 0
var _shots: String = "D:/src/playtest-20261020/evidence"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().title = "Global loading verification"
	get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(_shots)
	get_tree().current_scene = null
	_run.call_deferred()
	get_tree().create_timer(40.0).timeout.connect(func():
		print("GLOBAL_LOADING_TIMEOUT_STATE scene=", get_tree().current_scene, " resource_status=", ResourceLoader.load_threaded_get_status(SceneRouter.GAME_SCENE_PATH), " alpha=", SceneRouter.get("_loading_screen").modulate.a, " display=", DisplayServer.get_name())
		push_error("GLOBAL_LOADING_TIMEOUT")
		get_tree().quit(2)
	)

func _check(condition: bool, message: String) -> void:
	print("GLOBAL_LOADING ", "PASS " if condition else "FAIL ", message)
	if not condition:
		_failures += 1

func _settle() -> void:
	while SceneRouter.is_transitioning():
		await get_tree().process_frame
	await get_tree().process_frame

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots.path_join(label + ".png"))

func _run() -> void:
	_check(SceneRouter.goto_main_menu() == OK, "menu request accepted")
	_check(SceneRouter.goto_identity_setup() == ERR_BUSY, "duplicate request rejected")
	await _settle()
	_check(get_tree().current_scene.scene_file_path == SceneRouter.MAIN_MENU_SCENE_PATH, "menu ready before transition finishes")
	await _capture("01_main_menu")
	var menu: Node = get_tree().current_scene
	SaveManager.new_game()
	_check(SceneRouter.goto_identity_setup() == OK, "identity accepted")
	await get_tree().create_timer(0.08).timeout
	_check(get_tree().current_scene == menu, "old page retained during fade out")
	await get_tree().create_timer(0.15).timeout
	await _capture("02_loading_cover")
	await _settle()
	_check(get_tree().current_scene.scene_file_path == SceneRouter.IDENTITY_SETUP_SCENE_PATH, "identity ready")
	SaveManager.data.identity_id = IdentityOptions.CARDS[0].identity_id
	SaveManager.data.streamer_name = "加载验收"
	SaveManager.data.fan_group_name = "加载验收"
	SaveManager.data.tendency_state.initialize_from_identity_option(IdentityOptions.CARDS[0])
	_check(SceneRouter.goto_opening_room() == OK, "room accepted")
	await _settle()
	_check(get_tree().current_scene.scene_file_path == SceneRouter.OPENING_ROOM_SCENE_PATH, "room ready")
	await _capture("03_opening_room")
	_check(SceneRouter.goto_game() == OK, "battle accepted")
	await _settle()
	_check(get_tree().current_scene.scene_file_path == SceneRouter.GAME_SCENE_PATH, "production battle ready")
	_check(not get_tree().paused, "battle unpaused after reveal")
	await _capture("04_battle")
	get_tree().paused = true
	_check(SceneRouter.reload_current_scene() == OK, "reload accepted while paused")
	await _settle()
	_check(not get_tree().paused, "restart clears old pause")
	var saved_display: Dictionary = {"scripture": {"is_empty": true, "rows": []}, "religion_name": "加载验收"}
	_check(SceneRouter.goto_saved_ending(saved_display) == OK, "saved ending accepted")
	await _settle()
	_check(get_tree().current_scene is EndingPage, "ending routed")
	_check(get_tree().current_scene.get("_display_data").get("religion_name") == "加载验收", "ending snapshot delivered after ready")
	_check(SceneRouter.goto_comic(&"invalid") == ERR_INVALID_PARAMETER, "invalid comic rejected")
	_check(SceneRouter._request_scene("res://missing-loading-scene.tscn") == ERR_FILE_NOT_FOUND, "missing scene rejected before transition")
	_check(not SceneRouter.is_transitioning(), "invalid request leaves route unlocked")
	_check(SceneRouter.goto_main_menu() == OK, "return menu accepted")
	await _settle()
	var failures_received: Array = []
	SceneRouter.transition_failed.connect(func(_path: String, code: Error): failures_received.append(code), CONNECT_ONE_SHOT)
	get_tree().paused = true
	var retained_page: Node = get_tree().current_scene
	_check(SceneRouter._request_scene("TEST_ONLY_invalid_packed_scene", PackedScene.new()) == OK, "invalid packed scene enters async failure path")
	await _settle()
	_check(failures_received.size() == 1, "async failure reported once")
	_check(get_tree().current_scene == retained_page and get_tree().paused, "failure retains previous page and pause")
	var dialog: AcceptDialog = SceneRouter.get("_failure_dialog") as AcceptDialog
	_check(dialog.visible, "failure offers recovery action")
	dialog.get_ok_button().pressed.emit()
	await _settle()
	_check(not get_tree().paused and not dialog.visible, "recovery returns to usable menu")
	print("GLOBAL_LOADING_DONE failures=", _failures)
	get_tree().quit(_failures)
