extends Node
var converted: int = 0
func _ready() -> void:
	get_window().size = Vector2i(1920,1080)
	get_window().title = "Production battle performance verification"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	_run.call_deferred()
# 正式场景在96人口下实际移动、碰撞与感染，验证批量UI更新在完整接线中可用。
func _run() -> void:
	SaveManager.new_game()
	SaveManager.data.identity_id = IdentityOptions.CARDS[0].identity_id
	SaveManager.data.tendency_state.initialize_from_identity_option(IdentityOptions.CARDS[0])
	var scene: Node = load("res://scenes/sandbox/sandbox_plan_b.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(1.0).timeout
	var host: Node = scene.get_plan_b_battle_host()
	var sim: Node = scene.get("_plan_b_simulation")
	sim.set_random_seed(20261020)
	var ids: Array = sim.create_population(96,0)
	var player: Array = host.get_word_definitions("player")
	var opponent: Array = host.get_word_definitions("opponent")
	if player.is_empty() or opponent.is_empty():
		push_error("production words unavailable")
		get_tree().quit(1)
		return
	for index: int in ids.size():
		if index % 3 != 2:
			sim.seed_unit(ids[index], &"player" if index % 3 == 0 else &"opponent", player[0] if index % 3 == 0 else opponent[0], 100+index)
	sim.start_simulation()
	sim.contact_resolved.connect(func(_a,_b,outcome):
		if outcome == &"converted": converted += 1)
	await get_tree().create_timer(2.0).timeout
	var frames: Array[float] = []
	var cpu: Array[float] = []
	var physics: Array[float] = []
	var before := Time.get_ticks_usec()
	var start := before
	while Time.get_ticks_usec()-start < 15000000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		frames.append(float(now-before)/1000.0)
		before = now
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
	frames.sort()
	cpu.sort()
	physics.sort()
	var out := "D:/src/playtest-20261020/infection-production"
	DirAccess.make_dir_recursive_absolute(out)
	get_viewport().get_texture().get_image().save_png(out+"/battle.png")
	var ui: Node = scene.get_plan_b_battle_ui()
	var result := {"frames":frames.size(),"frame_p50_ms":frames[frames.size()/2],"frame_p95_ms":frames[int(frames.size()*0.95)],"cpu_p95_ms":cpu[int(cpu.size()*0.95)],"physics_p95_ms":physics[int(physics.size()*0.95)],"converted":converted,"counts":host.get_faction_counts(),"groups":sim.get_word_groups().size(),"stage":str(host.get_battle_state()),"ui":ui.get_pb14_performance_snapshot()}
	FileAccess.open(out+"/summary.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("INFECTION_PRODUCTION ",JSON.stringify(result))
	get_tree().quit(0 if converted > 0 else 1)
