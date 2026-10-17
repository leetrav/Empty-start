extends Control

## 仅为真人对比而组合生产组件；数字键/Tier是受控场景，不能视作正式通关。
const AREA = preload("res://systems/barrage_generation/barrage_area.tscn")
const AIM = preload("res://systems/combat_attack/aim_reticle.tscn")
const NUMERICS = preload("res://data/combat_stage/combat_numerics.tres")
const TIERS = preload("res://data/combat_stage/tier_catalog.tres")
const FEEDBACK = preload("res://systems/presentation/combat_hit_feedback.gd")
const IMPACT = preload("res://systems/presentation/barrage_impact_presenter.gd")
var area: BarrageArea
var aim: AimReticle
var attack: Node
var runtime = preload("res://systems/barrage_traits/barrage_trait_runtime.gd").new()
var catalog := BarrageTraitCatalog.new()
var hit: HitResolution
var stage: CombatStage
var profile: LevelProfile
var status: Label
var result_label: Label
var clock: float = 0.0
var level_index: int = 1
var tier: int = 3
var pressure: float = 0.15
var film: bool = false
var legacy_input: bool = false
var recovery_replay: bool = false
var replay_stage: int = 0
var motion: bool = false
var compact_curve: bool = false
var gallery_index: int = -1
var last_case: int = -1
var max_seconds: float = 0.0
var trails: Dictionary = {}
var charge_started: float = -1.0
var fired_at: float = -1.0
var full_logged: bool = false
var previous_phase: int = 0
var assisted_hold: bool = false


## 保留正式1024×1008区域、144判定、96视觉和原表时序；预览配置只写内存。
func _ready() -> void:
	seed(25503)
	get_window().title = "PTF-03 Combat Lab"
	theme = load("res://ui/theme/base_theme.tres")
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--legacy-input": legacy_input=true
		if arg == "--recovery-replay": recovery_replay=true; max_seconds=4.0
		if arg == "--pressure-b": pressure = 0.35
		if arg == "--motion-v0": motion = true
		if arg == "--motion-b": motion = true; compact_curve = true
		if arg == "--film": film = true; max_seconds = 24.0 if not motion else 12.0
	if legacy_input and not FileAccess.file_exists("res://.godot/ptf03_v0_attack.gd"):
		push_error("V0回放需从9da23042提取原攻击脚本到.godot/ptf03_v0_attack.gd并移除class_name行。")
		get_tree().quit(1)
		return
	area = AREA.instantiate()
	add_child(area)
	area.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	area.position = Vector2(448, 72)
	area.size = Vector2(1024, 1008)
	area.configure_combat_numerics(NUMERICS)
	area.configure_counterpressure(pressure)
	aim = AIM.instantiate()
	add_child(aim)
	attack = load("res://.godot/ptf03_v0_attack.gd").new() if legacy_input else AttackChargeInput.new()
	add_child(attack)
	attack.configure_target_query(aim, area)
	attack.configure_attack_timing(NUMERICS.create_attack_timing_config())
	attack.configure_combat_aim_radii(NUMERICS)
	catalog.load_production_tables()
	runtime.bind(area, catalog)
	area.barrage_generated.connect(func(view: BarrageView) -> void:
		var surface := view.get_glass_surface() as BarrageSpecialSurface
		if surface != null:
			surface.show_unselectable_marker = true # 两套压力预览共用候选标记，正式默认仍关闭。
			surface.queue_redraw())
	var fx = IMPACT.new()
	add_child(fx)
	if not legacy_input: fx.bind_attack(attack)
	var feedback = FEEDBACK.new()
	add_child(feedback)
	if not legacy_input: feedback.bind_attack(attack)
	status = _label(Vector2(20, 20), Vector2(1880, 45), 22)
	result_label = _label(Vector2(20, 550), Vector2(400, 470), 24)
	var help := _label(Vector2(20, 90), Vector2(400, 430), 23)
	help.text = "PTF-03 受控可玩对比台\n左键按住0.8s，松开发射\n1–4：主播；F2–F5：Tier\nA / B：压力15% / 35%\nM：四种运动；V：原跨度/短弧\nG：逐项六类特性与反制\nN：首关T0自由练习（不强推PK）\nSpace：预览辅助按住/释放\nEsc：退出；方案尚待真人选择"
	attack.shot_snapshot_created.connect(func(_snapshot: AttackTargetSnapshot) -> void:
		fired_at = clock
		print("PTF03_RELEASE clock=%.3f held_to_release=%.3f" % [clock, clock - charge_started]))
	attack.shot_hit_resolution_submitted.connect(_on_submission)
	_reset_case()
	if motion: _motion_case()


## 预览说明不使用业务NodePath，也不承担正式HUD职责。
func _label(at: Vector2, extent: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.size = extent
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 4096
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label


## 每个受控场景从正式关卡建独立PK对象，之后只有实际命中改变PK。
func _reset_case() -> void:
	attack.set_combat_active(false)
	area.clear_barrages()
	area.begin_combat_attempt()
	trails.clear()
	for child: Node in area.get_children():
		if child.has_meta("ptf03_decoration"): child.queue_free()
	profile = load("res://data/level_configuration/level_%03d.tres" % level_index)
	runtime.begin_attempt(profile)
	hit = HitResolution.new([0.50,0.60,0.67,0.75,0.85,0.95][tier], 0.0, 1.0, 0.02, 0.02, NUMERICS)
	stage = CombatStage.new(TIERS)
	stage.bind_hit_resolution(hit)
	stage.bind_barrage_area(area)
	stage.update_tier_for_pk(hit.get_player_pk())
	attack.configure_hit_resolution(hit)
	attack.set_combat_active(true)
	area.configure_counterpressure(pressure)
	area.start_normal_generation(profile)
	result_label.text = "受控起始PK %.1f%%\n后续只由实际攻击结算\n0.8s蓄力 / 0.2s飞行 / 0.15s硬直" % (hit.get_player_pk()*100.0)
	print("PTF03_CASE streamer=%s tier=%d pressure=%.2f" % [profile.streamer_id,tier,pressure])


## 整发真实结算后才显示数值与分裂，复用既有唯一PK规则。
func _on_submission(snapshot: AttackTargetSnapshot, submission: Dictionary) -> void:
	var result: Dictionary = submission.get("hit_resolution_result", {})
	result_label.text = "PK %.2f%%\n本发 %+.2f%%\n释放到结算 %.3fs\n命中实例 %d" % [hit.get_player_pk()*100.0, float(result.get("total_pk_delta",0))*100.0, clock-fired_at, result.get("target_results",[]).size()]
	print("PTF03_ARRIVAL flight=%.3f delta=%.4f targets=%d" % [clock-fired_at,float(result.get("total_pk_delta",0)),result.get("target_results",[]).size()])
	for target: Dictionary in result.get("target_results",[]):
		var traits := target.get("trait_result") as BarrageTraitResult
		if traits != null and traits.kind != BarrageTraitResult.Kind.OCCLUSION:
			area.end_barrage(int(target.get("target_instance_id",0)))
	runtime.on_shot_resolved(snapshot,submission,stage.get_current_tier(),null)


## 可玩阶段没有自动瞄准或自动开枪；film只切换受控展示用例。
func _process(delta: float) -> void:
	clock += delta
	if attack == null: return
	aim.set_charge_visual_state(attack.get_charge_progress(),attack.is_charge_held(),attack.is_fully_charged())
	if attack.is_charge_held() and charge_started < 0.0:
		charge_started = clock
		full_logged = false
	if attack.is_fully_charged() and not full_logged:
		full_logged = true
		print("PTF03_FULL actual_charge=%.3f" % (clock-charge_started))
	if not attack.is_charge_held(): charge_started = -1.0
	if previous_phase != int(attack.get_attack_phase()):
		if attack.get_attack_phase() == AttackChargeInput.AttackPhase.READY:
			print("PTF03_READY release_to_ready=%.3f" % (clock-fired_at))
		previous_phase = int(attack.get_attack_phase())
	status.text = "%s  T%d  PK %.2f%%  压力%.0f%%  蓄力%.0f%%  %s" % [profile.streamer_id,stage.get_current_tier(),hit.get_player_pk()*100,pressure*100,attack.get_charge_progress()*100,"四种运动对比" if motion else ("受控切换 / 无自动射击" if film else "可手动操作")]
	for id: int in trails:
		var view := instance_from_id(id) as BarrageView
		if is_instance_valid(view):
			# 运动对比只延长观察寿命，避免MovieMaker墙钟编码成本提前清空试件。
			view.runtime_record.expires_at_msec = Time.get_ticks_msec()+60000
			var line: Line2D = trails[id]
			line.add_point(view.position+view.size*0.5)
			if line.get_point_count()>600: line.remove_point(0)
	if recovery_replay:
		# 明确标注自动事件回放；它只复现硬直吞输入，不能作为人工操作验收。
		status.text = ("V0原脚本" if legacy_input else "修复版")+" · 自动输入回放：硬直内按住 / 0.8+0.2+0.15秒保持原案"
		var times: Array[float] = [0.2,1.1,1.4,2.5]
		if replay_stage<times.size() and clock>=times[replay_stage]:
			_preview_pointer(replay_stage%2==0)
			replay_stage+=1
		result_label.text += ""
	if film and not motion:
		var case_id := mini(int(clock/1.5),15)
		if case_id != last_case:
			last_case = case_id
			level_index = case_id/4+1
			tier = case_id%4+2
			_reset_case()
	if max_seconds>0.0 and clock>=max_seconds:
		print("PTF03_PREVIEW_COMPLETE duration=",clock)
		get_tree().quit()


## 真人切换场景用例；Space仅是可访问预览辅助，产品鼠标/触摸仍走生产输入。
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode==KEY_ESCAPE: get_tree().quit(); return
	if event.keycode==KEY_SPACE:
		assisted_hold = not assisted_hold
		_preview_pointer(assisted_hold)
		return
	if event.keycode in [KEY_1,KEY_2,KEY_3,KEY_4]: level_index = event.keycode-KEY_1+1
	elif event.keycode in [KEY_F2,KEY_F3,KEY_F4,KEY_F5]: tier = event.keycode-KEY_F2+2
	elif event.keycode==KEY_A: pressure=0.15
	elif event.keycode==KEY_B: pressure=0.35
	elif event.keycode==KEY_N: level_index=1; tier=0; motion=false
	elif event.keycode==KEY_M: motion=true; _reset_case(); _motion_case(); return
	elif event.keycode==KEY_V: compact_curve=not compact_curve; motion=true; _reset_case(); _motion_case(); return
	elif event.keycode==KEY_G: motion=false; gallery_index=(gallery_index+1)%6; _reset_case(); _trait_case(); return
	else: return
	motion=false
	_reset_case()


## 六类机制按已有21实际技能逐项生成；文字来自正式词库，解释只在测试侧栏。
func _trait_case() -> void:
	area.clear_barrages()
	var ids: Array[StringName] = [&"occlusion",&"split",&"reflect",&"retaliation_copy",&"fake_card",&"unselectable"]
	var explanations: Array[String] = ["铁板：整发-1%，无普通收益。绕开铁板后选露出的普通句。", "裂纹：命中分成两句；子句沿母体剩余寿命，不能再裂。", "果冻：反弹-1%，不叠加反击。移开准心选正常句。", "刷屏：两条独立水军复制品，每条-0.7%；复制品不继续复制。", "假复读：伪装成粉丝复读，误中-0.5%；比较灰色牌面与普通前景。", "禁选：符号标识；不能成为目标，仅它在圈内会落空-1%。换目标。"]
	var selected: StringName = ids[gallery_index]
	for skill: Dictionary in catalog.get_enabled_skills():
		if catalog.get_skill_trait_ids(skill).has(selected):
			var p: LevelProfile
			for index: int in range(1,5):
				p=load("res://data/level_configuration/level_%03d.tres"%index)
				if p.streamer_id==skill["streamer_id"]: break
			var special: BarrageView = runtime.spawn_skill(p,p.get_normal_speech_pool()[0],skill)
			if special!=null: special.position=Vector2(250,320)
			break
	var normal: BarrageView = area.spawn_normal_barrage(profile,profile.get_normal_speech_pool()[0])
	if normal!=null: normal.position=Vector2(150,570)
	result_label.text=explanations[gallery_index]+"\n（受控机制台，G下一类）"


## 同词、同速度45与同参数，用真实View四种运动对比；20秒仅延长观察，不改正式关卡。
func _motion_case() -> void:
	area.clear_barrages()
	for i: int in range(4):
		var view: BarrageView = area.spawn_normal_barrage(profile,profile.get_normal_speech_pool()[0])
		if view==null: continue
		view.position=Vector2(470,110+i*210)
		view.runtime_record.capture_lifetime_at_spawn(Time.get_ticks_msec(),20.0,1.0)
		view.configure_shared_motion(i,45.0,Vector2.LEFT,72.0,2.5,2.0,95.0,240.0 if compact_curve else 0.0)
		var line:=Line2D.new()
		line.width=2.0
		line.default_color=[Color.SKY_BLUE,Color.ORANGE,Color.VIOLET,Color.LIGHT_GREEN][i]
		line.set_meta("ptf03_decoration",true)
		area.add_child(line)
		trails[view.get_instance_id()]=line
		var caption := Label.new()
		caption.position=Vector2(20,110+i*210)
		caption.text=["直线","曲线","平缓加减速","低速游荡"][i]
		caption.set_meta("ptf03_decoration",true)
		area.add_child(caption)
	result_label.text="四种同词轨迹\n速度45px/s，上限95\n弧高72px，周期2.5s\n游荡2s改向\n曲线跨度："+("240px候选" if compact_curve else "原整区跨度")+"\n仅预览寿命20s；V比较\n参数选型尚未批准"


## 预览可访问控制与明确标注的回放都走同一Godot输入分发，产品入口不增加键盘发射。
func _preview_pointer(held: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=held
	event.position=get_viewport().get_final_transform()*(aim.get_canvas_transform()*Vector2(900,450))
	Input.parse_input_event(event)
	Input.flush_buffered_events()
