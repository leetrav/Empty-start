extends Node
var failures: int = 0
var terminal_events: Array = []
var flow_events: int = 0
var before_mode: bool = false
const GAME: PackedScene = preload("res://scenes/sandbox/sandbox_plan_b.tscn")
const OUT = "D:/src/playtest-20261020/pk-terminal"
func _ready() -> void:
	get_tree().current_scene = null
	SceneRouter.game_scene_override = GAME
	before_mode = "--before" in OS.get_cmdline_user_args()
	get_window().title = "PK terminal boundary runtime verification"
	get_window().size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(OUT)
	get_tree().create_timer(65.0).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()
# 正式各Boss组合场景：仅布置临界起点与固定人口，之后由Host逐帧自然推进PK并触发原终结链。
func _run() -> void:
	var catalog: LevelCatalog = load("res://data/level_configuration/level_catalog.tres")
	var levels: Array = [2] if before_mode else [0,1,2,3]
	for index: int in levels:
		SaveManager.new_game()
		SaveManager.data.identity_id = IdentityOptions.CARDS[0].identity_id
		SaveManager.data.tendency_state.initialize_from_identity_option(IdentityOptions.CARDS[0])
		SaveManager.data.next_normal_level_order = index+1
		for previous: int in index:
			SaveManager.data.completed_normal_level_ids.append(catalog.profiles[previous].level_id)
		_check(SceneRouter.goto_game() == OK,"route accepted")
		await _settle()
		var scene: Node = get_tree().current_scene
		var host: Node = scene.get_plan_b_battle_host()
		var sim: Node = scene.get("_plan_b_simulation")
		var flow: Node = scene.get_battle_attempt_flow()
		host.set_process(false)
		host.set_opponent_auto_publish_enabled_for_debug(false)
		sim.set_random_seed(20261020)
		var ids: Array = sim.create_population(68,0)
		var player: Array = host.get_word_definitions("player")
		var opponent: Array = host.get_word_definitions("opponent")
		for unit_index: int in ids.size():
			if unit_index < 61: sim.seed_unit(ids[unit_index],&"player",player[0],1)
			elif unit_index < 65: sim.seed_unit(ids[unit_index],&"opponent",opponent[0],2)
		# 冻结移动以固定截图中的61/4/3人数；战斗、PK、阶段、演出仍使用生产接线。
		sim.set_physics_process(false)
		if not before_mode:
			var display: Label = scene.get_plan_b_battle_ui().get("_pk_value_label")
			host.set_player_pk_for_debug(0.01)
			_check(display.text == "玩家 PK 1%","Host one percent is not full")
			host.set_player_pk_for_debug(0.004)
			_check(display.text == "玩家 PK <1%","positive low PK is not zero")
		host.set_player_pk_for_debug(0.95)
		var deadline := Time.get_ticks_msec()+10000
		while host.get_battle_state() != &"running" and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		_check(host.get_battle_state() == &"running","tier transition resumes")
		sim.set_physics_process(false)
		terminal_events.clear()
		flow_events = 0
		host.battle_ended.connect(func(result): terminal_events.append(str(result)))
		flow.pk_maximum_reached.connect(func(_a,_b,_c): flow_events += 1)
		# 设置旧实现可永久卡住的起点，先绘出HUD，然后开启真实Host._process。
		host.set("_pk",0.999995)
		host.pk_changed.emit(host.get_pk())
		await RenderingServer.frame_post_draw
		var label: Label = scene.get_plan_b_battle_ui().get("_pk_value_label")
		print("PK_GUI_START ",catalog.profiles[index].streamer_id," fraction=",host.get_pk_fraction()," label=",label.text)
		get_viewport().get_texture().get_image().save_png(OUT+("/before.png" if before_mode else "/near-limit.png"))
		if not before_mode: _check(label.text == "玩家 PK 99%","not full must not display 100")
		host.set_process(true)
		await get_tree().create_timer(1.0).timeout
		print("PK_GUI_RESULT ",catalog.profiles[index].streamer_id," fraction=",host.get_pk_fraction()," host=",host.get_battle_state()," events=",terminal_events," max_events=",flow_events)
		if before_mode:
			_check(host.get_pk_fraction() == 0.999995 and terminal_events.is_empty(),"original bug reproduced in real Gula scene")
		else:
			_check(host.get_pk_fraction() == 1.0,"real PK reaches exactly 1")
			_check(terminal_events == ["enter_contradiction"],"Host emits exactly one terminal event")
			_check(flow_events == 1,"formal flow receives one PK maximum")
			for tick: int in range(100): host.update_pk(1.0/60.0)
			_check(terminal_events.size() == 1 and flow_events == 1,"later frames do not repeat completion")
			await get_tree().create_timer(1.0).timeout
			get_viewport().get_texture().get_image().save_png(OUT+"/completed-"+catalog.profiles[index].streamer_id+".png")
			var contradiction = scene.get_contradiction_oracle_flow()
			var phase_deadline := Time.get_ticks_msec()+6000
			while not contradiction.is_contradiction_active() and Time.get_ticks_msec()<phase_deadline:
				await get_tree().process_frame
			_check(contradiction.is_contradiction_active(),"actual contradiction phase becomes active")
	print("PK_GUI_DONE failures=",failures," before=",before_mode)
	get_tree().quit(failures)
func _settle() -> void:
	while SceneRouter.is_transitioning(): await get_tree().process_frame
	await get_tree().process_frame
func _check(ok: bool,message: String) -> void:
	print("PK_GUI ","PASS " if ok else "FAIL ",message)
	if not ok:
		failures += 1
		push_error(message)
