extends Node
const GAME: PackedScene=preload("res://scenes/sandbox/sandbox_plan_b.tscn")
var failures := 0
var restarted := 0
var checks := 0
var shot_saved := false

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene=null
	get_window().size=Vector2i(1280,720)
	SceneRouter.game_scene_override=GAME
	get_tree().create_timer(60.0).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()

# 四关均由真实房间开播；预载正式PackedScene使暖缓存也必须显示加载提示。
func _run() -> void:
	var catalog: LevelCatalog=load("res://data/level_configuration/level_catalog.tres")
	for index in range(4):
		SaveManager.new_game()
		SaveManager.data.identity_id=IdentityOptions.CARDS[0].identity_id
		SaveManager.data.tendency_state.initialize_from_identity_option(IdentityOptions.CARDS[0])
		SaveManager.data.next_normal_level_order=index+1
		for previous in range(index): SaveManager.data.completed_normal_level_ids.append(catalog.profiles[previous].level_id)
		_check(SceneRouter.goto_opening_room()==OK,"room route accepted")
		await _settle(false)
		var room := get_tree().current_scene
		_check(room.start_live()==OK,"real room starts live "+str(index+1))
		_check(room.start_live()!=OK and SceneRouter.goto_game()==ERR_BUSY,"duplicate start rejected")
		await _settle(true)
		var scene := get_tree().current_scene
		_check(scene.get_battle_attempt_flow().get_current_level_profile().level_order==index+1,"correct level after cover")
		_check(not get_tree().paused and not SceneRouter.is_transitioning(),"battle revealed and running")
		if index==0:
			var host: Node=scene.get_plan_b_battle_host()
			host.set_player_pk_for_debug(0.0)
			# 失败演出自然结束后才显示按钮，不把首帧当作失败页已就绪。
			var deadline := Time.get_ticks_msec()+7000
			while not scene.get_node("%FailureOverlay").visible and Time.get_ticks_msec()<deadline:
				await get_tree().process_frame
			_check(scene.get_node("%FailureOverlay").visible,"real PK failure shows restart")
			scene.get_battle_attempt_flow().attempt_restarted.connect(func(_a,_b,_c,_d): restarted+=1)
			await _click(scene.get_node("%RestartButton"))
			_check(SceneRouter.is_transitioning(),"failure button uses loading cover")
			scene.restart_current_attempt()
			await _settle(true)
			_check(get_tree().current_scene==scene and restarted==1,"restart reuses same scene and rebuilds once")
			_check(host.get_battle_state()==&"running" and not scene.get_node("%FailureOverlay").visible,"failed live restarts successfully")
			scene.get_node("%PauseMenu").pause_game()
			scene.get_node("%PauseMenu").call("_on_reload_button_pressed")
			await _settle(true)
			_check(restarted==2 and not get_tree().paused,"paused restart reveals a running attempt")
	SceneRouter.game_scene_override=null
	print("LIVE_LOADING_DONE failures=",failures," checked_covers=",checks)
	get_tree().quit(failures)

# 检查完全遮罩持续时间、提示可见与黑幕期间的PK冻结，不用加载事件代替画面。
func _settle(expect_live: bool) -> void:
	var first := -1
	var last := -1
	var paused_ok := true
	var pk_by_attempt: Dictionary={}
	var frozen := true
	var screen: Control=SceneRouter.get("_loading_screen")
	while SceneRouter.is_transitioning():
		await get_tree().process_frame
		if expect_live and screen.visible and screen.modulate.a>=0.999 and screen.get("show_indicator"):
			var now := Time.get_ticks_msec()
			if first<0: first=now
			last=now
			paused_ok=paused_ok and get_tree().paused
			var current := get_tree().current_scene
			if current!=null and current.has_method("get_battle_attempt_flow"):
				var flow: Node=current.get_battle_attempt_flow()
				var key: int=flow.get_hit_resolution().get_instance_id()
				var pk: float=current.get_plan_b_battle_host().get_pk()
				if pk_by_attempt.has(key) and pk_by_attempt[key]!=pk: frozen=false
				pk_by_attempt[key]=pk
			if not shot_saved and now-first>100:
				shot_saved=true
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("D:/src/playtest-20261020/live-loading-cover.png")
	if expect_live:
		checks+=1
		print("LIVE_LOADING_COVER ",checks," opaque_indicator_ms=",last-first)
		# 帧首采样会漏掉两端不足一帧；0.6秒计时的可观测跨度允许100ms采样误差。
		_check(first>=0 and last-first>=500,"spinner remains visible through minimum cover")
		_check(paused_ok and frozen,"covered gameplay is frozen")
	await get_tree().process_frame

func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()*Vector2(get_window().size)/get_viewport().get_visible_rect().size
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
func _check(ok: bool, message: String) -> void:
	print("LIVE_LOADING ","PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
