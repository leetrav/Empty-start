extends Node
const SIM = preload("res://systems/plan_b/simulation/plan_b_unit_simulation.gd")
const HOST = preload("res://systems/plan_b/battle/plan_b_battle_host.gd")
const CATALOG = preload("res://systems/plan_b/content/plan_b_content_catalog.gd")
const DIRECTOR = preload("res://systems/plan_b/opponent/fermi_opponent_director.gd")
const UI = preload("res://ui/plan_b/plan_b_battle_ui.tscn")
const TRACKER = preload("res://systems/plan_b/performance/pb14_performance_tracker.gd")
var sim: Node
var ui: Control
var host: Node
var tracker: Node
var out: String = "D:/src/playtest-20261020/infection-before"
var failures: int = 0
var converted: int = 0
var burst_usec: Array[int] = []
var frame_ms: Array[float] = []
var gpu_ms: Array[float] = []
func _ready() -> void:
	if "--after" in OS.get_cmdline_user_args():
		out = out.replace("before", "after")
	DirAccess.make_dir_recursive_absolute(out)
	get_window().title = "Infection frame performance verification"
	get_window().size = Vector2i(1920,1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	_run.call_deferred()
# 使用真实模块与96人口；固定每组输入，只注入测试接触，不改变生产规则。
func _run() -> void:
	sim = SIM.new()
	host = HOST.new()
	host.add_child(sim)
	add_child(host)
	var catalog = CATALOG.new()
	var director = DIRECTOR.new()
	_check(host.configure_modules(sim,catalog,director), "modules configured")
	ui = UI.instantiate()
	add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bounds := Rect2(448,72,1024,828)
	ui.set_world_bounds(bounds)
	ui.bind_sources(host,sim,catalog)
	host.start_battle(bounds.size,bounds.position)
	host.pause_battle()
	host.set_process(false)
	var words: Array = host.get_word_definitions("player")
	_check(not words.is_empty(), "real words available")
	var word: Dictionary = words[0].duplicate(true)
	word["strength"] = 3
	sim.set_random_seed(20261020)
	var ids: Array = sim.create_population(96,0)
	for index: int in ids.size():
		sim.seed_unit(ids[index], &"opponent", word, 1)
	var units: Dictionary = sim.get("_units_by_id")
	var source = units[ids[0]]
	source.apply_word_snapshot(&"player",word,2)
	sim.unit_changed.emit(source.unit_id,&"convert")
	sim.contact_resolved.connect(func(_a,_b,result):
		if result == &"converted": converted += 1)
	for i: int in range(60): await RenderingServer.frame_post_draw
	tracker = TRACKER.new()
	tracker.configure(out+"/sections.jsonl")
	tracker.set_runtime_sources(host,sim,ui,null)
	add_child(tracker)
	sim.set_performance_tracker(tracker)
	ui.set_performance_tracker(tracker)
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	# 相同16目标、固定随机流，每批重新恢复接触前状态，分别记录裁决峰值和绘制帧时。
	for batch: int in range(40):
		for index: int in range(1,17):
			units[ids[index]].apply_word_snapshot(&"opponent",word,1)
			sim.unit_changed.emit(ids[index],&"convert")
		await RenderingServer.frame_post_draw
		var before := Time.get_ticks_usec()
		for index: int in range(1,17):
			sim.call("_attempt_conversion",source,units[ids[index]])
		burst_usec.append(Time.get_ticks_usec()-before)
		await RenderingServer.frame_post_draw
		frame_ms.append(float(Time.get_ticks_usec()-before)/1000.0)
		gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		# 绘制前必须已反映实际阵营，不能以丢事件换取性能。
		var field: Control = ui.get("_field")
		var shown: Dictionary = field.get("_snapshots_by_id")
		for id in ids:
			_check(shown.has(str(id)) and shown[str(id)]["team"] == str(units[id].team), "display reflects actual faction")
	get_viewport().get_texture().get_image().save_png(out+"/battle.png")
	var measured_counts: Dictionary = sim.get_faction_counts()
	# 同帧清场/重建后只保留新局最终状态，不让待刷新队列带回旧棋子。
	sim.clear_population()
	var restarted_ids: Array = sim.create_population(8,0)
	for id in restarted_ids:
		sim.seed_unit(id, &"player", word, 3)
	await RenderingServer.frame_post_draw
	var rendered: Dictionary = ui.get("_field").get("_snapshots_by_id")
	_check(rendered.size() == 8, "clear and restart discard old displayed units")
	for id in restarted_ids:
		_check(rendered.has(str(id)) and rendered[str(id)]["team"] == "player", "restart shows final faction")
	burst_usec.sort()
	frame_ms.sort()
	gpu_ms.sort()
	var result := {"burst_p50_ms":burst_usec[20]/1000.0,"burst_p95_ms":burst_usec[38]/1000.0,"burst_max_ms":burst_usec[-1]/1000.0,"frame_p50_ms":frame_ms[20],"frame_p95_ms":frame_ms[38],"gpu_p50_ms":gpu_ms[20],"converted":converted,"failures":failures,"population":measured_counts,"frames":40}
	FileAccess.open(out+"/summary.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("INFECTION_RESULT ",JSON.stringify(result))
	get_tree().quit(0 if failures == 0 else 1)
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
