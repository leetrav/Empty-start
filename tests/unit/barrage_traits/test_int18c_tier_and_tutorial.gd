extends SceneTree

const RUNTIME = preload("res://systems/barrage_traits/barrage_trait_runtime.gd")
const HINT = preload("res://ui/tutorial/tutorial_hint_view.tscn")
const AIM = preload("res://systems/combat_attack/aim_reticle.tscn")
const AREA = preload("res://systems/barrage_generation/barrage_area.tscn")
const TIERS = preload("res://data/combat_stage/tier_catalog.tres")
const NUMERICS = preload("res://data/combat_stage/combat_numerics.tres")
const PK: Array[float] = [0.50, 0.60, 0.67, 0.75, 0.85, 0.95]
var failures: int = 0
var catalog := BarrageTraitCatalog.new()
var canvas: Control


## 复用生产区域、正式目录和真实 Tier 广播，不用目录替身绕过抽选链。
func _initialize() -> void:
	call_deferred("_run")


## 汇总可复现失败，进程退出码与日志同时体现验收结果。
func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("INT18C FAIL: " + message)


## 四关首次升档、容量回填与实例生命周期使用相同生产入口。
func _run() -> void:
	seed(1816)
	root.size = Vector2i(1920, 1080)
	canvas = Control.new()
	canvas.size = Vector2(1920, 1080)
	canvas.theme = load("res://ui/theme/base_theme.tres")
	root.add_child(canvas)
	_expect(catalog.load_production_tables(), "正式目录加载")
	for index: int in range(1, 5):
		await _verify_level(index)
	await _verify_lifecycle()
	await _verify_tutorial()
	print("INT18C_RUNTIME_PASS" if failures == 0 else "INT18C_RUNTIME_FAIL count=%d" % failures)
	quit(0 if failures == 0 else 1)


## 只从在树且尚未结束的真实实例统计特性，避免读取生成器内部队列。
func _specials(area: BarrageArea) -> Array[BarrageView]:
	var result: Array[BarrageView] = []
	for child: Node in area.get_children():
		if child is BarrageView and not child.is_queued_for_deletion():
			var view := child as BarrageView
			if not view.runtime_record.trait_set.get_trait_ids().is_empty():
				result.append(view)
	return result


## 实例化与正式 Sandbox 相同的区域 Scene；静态关卡与数值资源始终只读。
func _new_area(at: Vector2, extent: Vector2) -> BarrageArea:
	var area := AREA.instantiate() as BarrageArea
	canvas.add_child(area)
	area.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	area.position = at
	area.size = extent
	area.configure_combat_numerics(NUMERICS)
	return area


## 验收说明只出现在测试画面，不进入正式产品 UI。
func _label(at: Vector2, text: String) -> Label:
	var label := Label.new()
	label.position = at
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	canvas.add_child(label)
	return label


## 当前四关 T2～T5 均在普通批次生成一项，并在降档回升时保持首次抽选语义。
func _verify_level(index: int) -> void:
	var profile := load("res://data/level_configuration/level_%03d.tres" % index) as LevelProfile
	var area: BarrageArea = _new_area(Vector2(30 + ((index - 1) % 2) * 945, 75 + ((index - 1) / 2) * 490), Vector2(910, 430))
	var runtime = RUNTIME.new()
	runtime.bind(area, catalog)
	runtime.begin_attempt(profile)
	area.begin_combat_attempt()
	var stage := CombatStage.new(TIERS)
	stage.bind_barrage_area(area)
	stage.begin_combat()
	_expect(area.start_normal_generation(profile), "正式关启动普通生成")
	area.stop_normal_generation()
	for tier: int in range(2, 6):
		area.clear_current_barrages()
		stage.update_tier_for_pk(PK[tier])
		_expect(stage.get_current_tier() == tier, "真实 PK 进入指定 Tier")
		area.spawn_normal_batch_now()
		var actual: Array[BarrageView] = _specials(area)
		_expect(actual.size() == (2 if not actual.is_empty() and actual[0].runtime_record.trait_set.is_retaliation_copy() else 1), "%s T%d 首次技能进入普通批次" % [profile.streamer_id, tier])
		if not actual.is_empty():
			var ids: Array[StringName] = actual[0].runtime_record.trait_set.get_trait_ids()
			var in_pool: bool = false
			for skill: Dictionary in catalog.get_enabled_skills(profile.streamer_id, tier):
				in_pool = in_pool or catalog.get_skill_trait_ids(skill) == ids
			_expect(in_pool, "生成特性来自当前主播/Tier 的21表")
			var override_s: float = catalog.get_lifetime_override(ids)
			if override_s > 0.0:
				var affected: bool = ids.has(BarrageTraitSet.SPLIT)
				var expected: float = override_s * (TIERS.get_tier_config(tier).lifetime_multiplier if affected else 1.0)
				_expect(actual[0].runtime_record.lifetime_duration_msec == roundi(expected * 1000.0), "07 覆盖与当前 Tier 寿命只计算一次")
			print("INT18C_TIER streamer=%s tier=%d traits=%s ttl_ms=%d" % [profile.streamer_id, tier, ids, actual[0].runtime_record.lifetime_duration_msec])
		area.clear_current_barrages()
		stage.update_tier_for_pk(PK[tier - 1])
		area.spawn_normal_batch_now()
		_expect(_specials(area).is_empty(), "降档后没有重复派发已消费技能")
		area.clear_current_barrages()
		stage.update_tier_for_pk(PK[tier])
		area.spawn_normal_batch_now()
		_expect(_specials(area).is_empty(), "回升同档没有重新抽取")
	# 第二次尝试会重新抽选；满特殊容量保留待项，降档暂停它，回升后补入。
	area.clear_barrages()
	area.begin_combat_attempt()
	stage.begin_combat()
	area.start_normal_generation(profile)
	area.stop_normal_generation()
	area.clear_current_barrages()
	var blockers: Array[BarrageView] = []
	for slot: int in range(profile.special_instance_screen_cap):
		var blocker: BarrageView = runtime.spawn_skill(profile, profile.get_normal_speech_pool()[0], catalog.get_enabled_skills(profile.streamer_id, 2)[0])
		_expect(blocker != null, "正式特殊容量可填满")
		if blocker != null:
			blockers.append(blocker)
	stage.update_tier_for_pk(PK[2])
	area.spawn_normal_batch_now()
	_expect(_specials(area).size() == profile.special_instance_screen_cap, "满特殊容量没有透支")
	_expect(int(area.get_current_barrage_counts()["normal"]) > blockers.size(), "特殊满时普通批次继续")
	area.clear_current_barrages()
	stage.update_tier_for_pk(PK[1])
	area.spawn_normal_batch_now()
	_expect(_specials(area).is_empty(), "降档暂停未生成高档技能")
	area.clear_current_barrages()
	stage.update_tier_for_pk(PK[2])
	area.spawn_normal_batch_now()
	_expect(_specials(area).size() in [1, 2], "回升后待技能实际补入，复制为一对")
	area.stop_normal_generation()
	for child: Node in area.get_children():
		if child is BarrageView:
			child.set_process(false)
	_label(area.position - Vector2(0, 38), "%s · T2→T5 首次生成 / 回档 / 容量补入 PASS" % profile.streamer_id)
	print("INT18C_LEVEL_PASS streamer=%s first_entries=4 retry=reset pending=retained" % profile.streamer_id)
	runtime.unbind()
	await process_frame
	if index == 4:
		await _capture("D:/tmp/INT18C_four_levels_2026-10-16.png")
		for child: Node in canvas.get_children():
			child.queue_free()
		await process_frame


## T5 分裂截止、合法一代复制和叠加容量直接复现正式组件生命周期。
func _verify_lifecycle() -> void:
	var profile := load("res://data/level_configuration/level_001.tres") as LevelProfile
	var area: BarrageArea = _new_area(Vector2(448, 72), Vector2(1024, 1008))
	var runtime = RUNTIME.new()
	runtime.bind(area, catalog)
	runtime.begin_attempt(profile)
	var stage := CombatStage.new(TIERS)
	stage.bind_barrage_area(area)
	stage.update_tier_for_pk(PK[5])
	var speech: LevelSpeech = profile.get_normal_speech_pool()[0]
	var parent: BarrageView = runtime.spawn_skill(profile, speech, catalog.get_enabled_skills("alien", 3)[0])
	_expect(parent != null and parent.runtime_record.lifetime_duration_msec == 2400, "split T5 寿命精确2.4秒")
	if parent != null:
		await create_timer(0.05).timeout
		var expiry: int = parent.runtime_record.expires_at_msec
		var children: Array[BarrageView] = runtime.split_on_normal_hit(parent)
		_expect(children.size() == 2, "真实生成两子体")
		for child: BarrageView in children:
			_expect(child.runtime_record.expires_at_msec == expiry, "子体沿用已消耗时间后的母体截止")
			_expect(child.runtime_record.lifetime_duration_msec == 2400, "子体没有二次覆盖为6秒")
			_expect(runtime.split_on_normal_hit(child).is_empty(), "子片禁止再次分裂")
	area.clear_current_barrages()
	var source: BarrageView = area.spawn_normal_barrage(profile, speech)
	var copy: BarrageView = runtime.spawn_retaliation_copy(source, profile)
	_expect(copy != null, "普通源生成合法复制品")
	_expect(runtime.spawn_retaliation_copy(copy, profile) == null, "复制链仅一代")
	area.end_barrage(source.get_instance_id())
	_expect(runtime.spawn_retaliation_copy(source, profile) == null, "已结束源不能复制")
	area.clear_current_barrages()
	var stacked_profile := profile.duplicate() as LevelProfile
	stacked_profile.special_trait_ids = ["reflect", "fake_card"]
	var ids: Array[StringName] = [BarrageTraitSet.REFLECT, BarrageTraitSet.FAKE_CARD]
	for slot: int in range(profile.special_instance_screen_cap):
		_expect(area.spawn_normal_barrage(stacked_profile, speech, ids) != null, "叠加特性每实例仅一名额")
	_expect(area.spawn_normal_barrage(stacked_profile, speech, ids) == null, "叠加仍遵守正式上限")
	_expect(area.spawn_normal_barrage(profile, speech) != null, "叠加满不阻塞普通实例")
	print("INT18C_LIFECYCLE split_t5_ms=2400 expiry=inherited copy=one_generation stacked_cap=%d" % profile.special_instance_screen_cap)
	runtime.unbind()
	area.queue_free()
	await process_frame


## 用真实输入分发与帧计时走三步，提示只通过 D 的公开绑定接口显示。
func _verify_tutorial() -> void:
	var profile := load("res://data/level_configuration/level_001.tres") as LevelProfile
	var speech: LevelSpeech = profile.get_normal_speech_pool()[0]
	var area: BarrageArea = _new_area(Vector2(448, 72), Vector2(1024, 1008))
	var aim := AIM.instantiate() as AimReticle
	canvas.add_child(aim)
	var attack := AttackChargeInput.new()
	canvas.add_child(attack)
	attack.configure_target_query(aim, area)
	attack.configure_attack_timing(NUMERICS.create_attack_timing_config())
	attack.configure_combat_aim_radii(NUMERICS)
	var hit := HitResolution.new(0.5, 0.0, 1.0, 0.02, 0.02, NUMERICS)
	attack.configure_hit_resolution(hit)
	area.start_normal_generation(profile)
	area.stop_normal_generation()
	area.clear_current_barrages()
	var runner := TutorialStepRunner.new()
	var hint = HINT.instantiate()
	canvas.add_child(hint)
	hint.position = Vector2(500, 900)
	hint.size = Vector2(920, 90)
	hint.bind_runner(runner)
	var completed: Array[String] = []
	var submissions: Array[Dictionary] = []
	runner.step_completed.connect(func(id: String) -> void: completed.append(id))
	attack.shot_hit_resolution_submitted.connect(func(snapshot: AttackTargetSnapshot, submission: Dictionary) -> void:
		submissions.append(submission)
		# 与正式 Flow 一致：结束命中目标后，同步交出已结算事实；此处不替代 Flow 存档逻辑。
		for target_result: Dictionary in submission.get("hit_resolution_result", {}).get("target_results", []):
			area.end_barrage(int(target_result.get("target_instance_id", 0)))
		runner.on_shot_resolved(snapshot, submission, 0, null))
	var target: BarrageView = area.spawn_normal_barrage(profile, speech)
	target.position = Vector2(150, 300)
	target.set_process(false)
	await process_frame
	var point: Vector2 = target.get_global_rect().get_center()
	runner.begin(profile.tutorial_config_id)
	_mouse_motion(aim, point)
	target.hide()
	runner.observe_combat_frame(area, aim, attack)
	_expect(runner.get_current_hint().is_empty(), "隐藏普通目标不触发教学")
	hint.clear_hint()
	runner.begin(profile.tutorial_config_id)
	target.show()
	paused = true
	runner.observe_combat_frame(area, aim, attack)
	_expect(runner.get_active_step_id() == "tutorial_001_aim", "暂停时几何观察不推进")
	paused = false
	runner.observe_combat_frame(area, aim, attack)
	_expect(runner.get_active_step_id() == "tutorial_001_charge" and hint.visible, "真实准心重叠完成aim并显示charge提示")
	# 提前抬手保持 charge，且不产生发射提交。
	_mouse_button(aim, point, true)
	await create_timer(0.08).timeout
	_mouse_button(aim, point, false)
	runner.observe_combat_frame(area, aim, attack)
	_expect(not attack.is_charge_held() and submissions.is_empty() and runner.get_active_step_id() == "tutorial_001_charge", "提前松开保留charge")
	# 失败重开只保留已完成的 aim；由组合方重置攻击对象并再次 begin。
	var saved: Array[String] = runner.get_completed_step_ids()
	attack.set_combat_active(false)
	attack.set_combat_active(true)
	hint.clear_hint()
	runner.begin(profile.tutorial_config_id, saved)
	_expect(runner.get_current_hint().get("step_id") == "tutorial_001_charge" and hint.visible, "重开恢复已完成aim后的提示")
	_mouse_button(aim, point, true)
	await create_timer(0.12).timeout
	var before_pause: float = attack.get_charge_progress()
	paused = true
	await create_timer(0.15).timeout
	runner.observe_combat_frame(area, aim, attack)
	_expect(is_equal_approx(attack.get_charge_progress(), before_pause), "暂停中真实蓄力冻结")
	_expect(runner.get_active_step_id() == "tutorial_001_charge", "暂停不完成charge")
	paused = false
	await create_timer(NUMERICS.charge_time_seconds).timeout
	runner.observe_combat_frame(area, aim, attack)
	_expect(attack.is_fully_charged() and runner.get_active_step_id() == "tutorial_001_fire", "真实帧满蓄完成charge")
	aim.set_charge_visual_state(attack.get_charge_progress(), attack.is_charge_held(), attack.is_fully_charged())
	_label(Vector2(448, 24), "INT-18C · 首关真实输入 / 满蓄 / 暂停 / 进度恢复")
	await process_frame
	await _capture("D:/tmp/INT18C_tutorial_fire_2026-10-16.png")
	# 满蓄射空保持 fire；该目标移开，让既有扫描和 HitResolution 自己判落空。
	_mouse_motion(aim, Vector2(100, 100))
	_mouse_button(aim, Vector2(100, 100), false)
	await create_timer(NUMERICS.projectile_flight_seconds + NUMERICS.recovery_time_seconds + 0.1).timeout
	_expect(submissions.size() == 1 and runner.get_active_step_id() == "tutorial_001_fire", "射空保持fire")
	area.end_barrage(target.get_instance_id())
	# 真实复读命中不能完成教程，继续沿既有 RepeatPlan 与生成接口。
	var plan := RepeatPlan.create_normal_hit_plan(StringName(speech.original_sentence_id), speech.text, 0, 1, 3.0, speech.tendency_id)
	var repeat: BarrageView = area.spawn_repeat_barrage(plan, true)
	_expect(repeat != null, "实际复读实例生成")
	if repeat != null:
		repeat.position = Vector2(150, 300)
		repeat.set_process(false)
		await _fire_at(aim, attack, repeat.get_global_rect().get_center())
		_expect(submissions.size() == 2 and runner.get_active_step_id() == "tutorial_001_fire", "实际复读命中仍停留fire")
		if submissions.size() == 2:
			var results: Array = submissions.back().get("hit_resolution_result", {}).get("target_results", [])
			_expect(not results.is_empty() and bool(results[0].get("is_repeat", false)), "复读实际进入结算而非落空")
	# 新普通目标走真实扫描、飞行、HitResolution，最后一次性完成。
	target = area.spawn_normal_barrage(profile, speech)
	target.position = Vector2(150, 300)
	target.set_process(false)
	await _fire_at(aim, attack, target.get_global_rect().get_center())
	_expect(submissions.size() == 3 and runner.get_active_step_id().is_empty() and not hint.visible, "真实普通命中完成并隐藏提示")
	_expect(not runner.notify_event("tutorial_normal_hit"), "重复命中事实不重复完成")
	var all_completed: Array[String] = runner.get_completed_step_ids()
	_expect(all_completed.size() == 3, "只有正式三步被记入完成列表")
	# UI/运行器重建模拟保存后恢复，不向存档对象发明字段。
	var restored := TutorialStepRunner.new()
	hint.bind_runner(restored)
	_expect(not restored.begin(profile.tutorial_config_id, all_completed) and not hint.visible, "全部完成后重建不重播教学")
	all_completed.clear()
	_expect(restored.get_completed_step_ids().size() == 3, "恢复进度副本独立")
	print("INT18C_TUTORIAL_PASS input=parse_input_event undercharge=retained pause=frozen restart=restored miss=retained repeat=excluded normal=completed ui=hidden")
	attack.set_combat_active(false)
	area.queue_free()
	attack.queue_free()
	aim.queue_free()
	hint.queue_free()
	await process_frame


## 从画布位置换算窗口事件，沿已有 KT-30 / INT-17A 的输入路径。
func _mouse_motion(aim: AimReticle, point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * (aim.get_canvas_transform() * point)
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## 发射仅注入真实按下/松开，不直接调用生产 _input 或推进生产 _process。
func _mouse_button(aim: AimReticle, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = root.get_final_transform() * (aim.get_canvas_transform() * point)
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## 实际帧时序蓄力、飞行与硬直；不缩短正式数值配置。
func _fire_at(aim: AimReticle, attack: AttackChargeInput, point: Vector2) -> void:
	_mouse_motion(aim, point)
	_mouse_button(aim, point, true)
	await create_timer(NUMERICS.charge_time_seconds + 0.05).timeout
	_expect(attack.is_fully_charged(), "输入驱动实际满蓄")
	_mouse_button(aim, point, false)
	await create_timer(NUMERICS.projectile_flight_seconds + NUMERICS.recovery_time_seconds + 0.1).timeout


## 图像只输出到本机 D 盘，headless 回归不等待绘制帧。
func _capture(path: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(path)
		print("INT18C_PREVIEW ", path)
