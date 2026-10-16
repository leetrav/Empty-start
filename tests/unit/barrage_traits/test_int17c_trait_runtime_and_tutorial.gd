extends SceneTree

const AREA = preload("res://systems/barrage_generation/barrage_area.tscn")
const RUNTIME = preload("res://systems/barrage_traits/barrage_trait_runtime.gd")
const NUMERICS = preload("res://data/combat_stage/combat_numerics.tres")
const HINT = preload("res://ui/tutorial/tutorial_hint_label.gd")
var failures: int = 0


## 正式四关、32 技能和现有场景构成直接运行验收，失败明确退出。
func _initialize() -> void:
	call_deferred("_run")


## 汇总外部行为断言，保证失败后给出明确进程退出码。
func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("INT17C FAIL: " + message)


## 通过正式目录、生产组件和输入处理器执行整条事实链。
func _run() -> void:
	seed(1707)
	root.size = Vector2i(1920, 1080)
	var catalog := BarrageTraitCatalog.new()
	_expect(catalog.load_production_tables(), "formal tables load")
	var profiles: Dictionary = {}
	for index: int in range(1, 5):
		var profile := load("res://data/level_configuration/level_%03d.tres" % index) as LevelProfile
		_expect(profile != null and not profile.get_normal_speech_pool().is_empty(), "real level loads")
		if profile != null:
			profiles[profile.streamer_id] = profile
	var area := AREA.instantiate() as BarrageArea
	root.add_child(area)
	area.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	area.position = Vector2(448, 72)
	area.size = Vector2(1024, 1008)
	area.set_foreground_slot_count(12)
	var numerics := NUMERICS.duplicate(true) as CombatNumericsConfig
	area.configure_combat_numerics(numerics)
	var runtime = RUNTIME.new()
	_expect(runtime.bind(area, catalog), "runtime binds actual area")
	var generated: Array[String] = []
	runtime.counter_skill_spawned.connect(func(id: String, _tier: int, _view: BarrageView) -> void: generated.append(id))
	await process_frame
	for skill: Dictionary in catalog.get_enabled_skills():
		var profile: LevelProfile = profiles[str(skill["streamer_id"])]
		var original_traits: Array[String] = profile.special_trait_ids.duplicate()
		var view: BarrageView = runtime.spawn_skill(profile, profile.get_normal_speech_pool()[0], skill)
		_expect(view != null, "formal skill actually generates: " + str(skill["skill_id"]))
		if view != null:
			var ids: Array[StringName] = catalog.get_skill_trait_ids(skill)
			_expect(view.runtime_record.trait_set.get_trait_ids() == ids, "skill traits match 21")
			var lifetime: float = catalog.get_lifetime_override(ids)
			if lifetime > 0.0:
				_expect(view.runtime_record.lifetime_duration_msec == roundi(lifetime * 1000.0), "07 lifetime consumed")
			area.clear_current_barrages()
			print("INT17C_SKILL id=", skill["skill_id"], " tier=", skill["tier"], " streamer=", profile.streamer_id)
		_expect(profile.special_trait_ids == original_traits, "static profile stays unchanged")
	_expect(generated.size() == 32, "all 32 enabled skills physically spawned")
	print("INT17C_SKILLS_PASS actual_generated=", generated.size(), " profiles=", profiles.keys())
	var rng := RandomNumberGenerator.new()
	rng.seed = 1721
	for streamer: String in profiles:
		var weighted_profile: LevelProfile = profiles[streamer]
		for tier: int in range(2, 6):
			var seen: Dictionary = {}
			for draw: int in range(16):
				var weighted_view: BarrageView = runtime.spawn_counter_skill(weighted_profile, weighted_profile.get_normal_speech_pool()[0], tier, rng)
				_expect(weighted_view != null, "weighted public spawn succeeds after Tier change")
				if weighted_view != null:
					seen[generated.back()] = true
					area.clear_current_barrages()
			_expect(seen.size() == 2, "both enabled weighted entries appear in each streamer/Tier pool")
	print("INT17C_WEIGHTED_PASS pools=16 draws=256 all_candidates_observed=true")

	var alien: LevelProfile = profiles["alien"]
	var speech: LevelSpeech = alien.get_normal_speech_pool()[0]
	var split_skill: Dictionary = catalog.get_enabled_skills("alien", 3)[0]
	var parent: BarrageView = runtime.spawn_skill(alien, speech, split_skill)
	var original_expiry: int = parent.runtime_record.expires_at_msec
	var children: Array[BarrageView] = []
	runtime.split_children_spawned.connect(func(_id: int, actual: Array[BarrageView], _requested: int) -> void: children.assign(actual))
	var parent_id: int = parent.get_instance_id()
	area.end_barrage(parent_id)
	# 复现 BattleAttemptFlow 先释放母体、同帧同步广播 shot_resolved 的正式调用顺序。
	runtime.on_shot_resolved(null, {"hit_resolution_result": {"target_results": [{"target_instance_id": parent_id, "is_valid_hit": true, "is_repeat": false}]}}, 3, null)
	_expect(children.size() == 2, "07 split_child_count generates two actual children")
	for child: BarrageView in children:
		_expect(child.runtime_record.expires_at_msec == original_expiry, "child keeps absolute expiry")
		_expect(child.runtime_record.original_sentence_id == speech.original_sentence_id, "child keeps original id")
		_expect(runtime.split_on_normal_hit(child).is_empty(), "child cannot split recursively")
	area.clear_current_barrages()
	var source: BarrageView = area.spawn_normal_barrage(alien, speech)
	var copy: BarrageView = runtime.spawn_retaliation_copy(source, alien)
	_expect(copy != null and copy.runtime_record.trait_set.is_retaliation_copy(), "actual retaliation copy")
	_expect(runtime.spawn_retaliation_copy(copy, alien) == null, "copy does not copy")
	area.clear_current_barrages()

	for trait_id: StringName in [BarrageTraitSet.FAKE_CARD, BarrageTraitSet.RETALIATION_COPY, BarrageTraitSet.REFLECT, BarrageTraitSet.OCCLUSION]:
		var traits := BarrageTraitSet.new()
		traits.add_trait(trait_id)
		catalog.configure_trait_set(traits)
		var trait_result: BarrageTraitResult = traits.get_hit_result()
		var hit := HitResolution.new(0.5, 0.0, 1.0, 0.02, 0.02, numerics)
		var anomaly: HitResolution.ShotAnomaly = HitResolution.ShotAnomaly.NONE
		if trait_id == BarrageTraitSet.REFLECT:
			anomaly = HitResolution.ShotAnomaly.BOUNCE
		elif trait_id == BarrageTraitSet.OCCLUSION:
			anomaly = HitResolution.ShotAnomaly.OBSTRUCTION
		var targets: Array[Dictionary] = [{"trait_result": trait_result, "is_valid_hit": true, "pk_delta": 0.5, "tendency_delta": 10}]
		var result: Dictionary = hit.resolve_shot_results(targets, anomaly)
		_expect(is_equal_approx(float(result["total_pk_delta"]), float(numerics.get(trait_result.penalty_param_id))), "07 penalty ID consumed by actual HitResolution")
		_expect(int(result["target_results"][0]["tendency_delta"]) == 0, "special hit has zero ordinary reward")
	var mapped := BarrageTraitResult.new(BarrageTraitResult.Kind.FAKE_CARD)
	mapped.penalty_param_id = "reflect_penalty_pk"
	var mapped_hit := HitResolution.new(0.5, 0.0, 1.0, 0.02, 0.02, numerics)
	var mapped_targets: Array[Dictionary] = [{"trait_result": mapped, "pk_delta": 0.5}]
	_expect(is_equal_approx(float(mapped_hit.resolve_shot_results(mapped_targets)["total_pk_delta"]), numerics.reflect_penalty_pk), "parameter ID drives value rather than fixed kind")
	print("INT17C_TRAITS_PASS split=2 copy_chain_stopped=true penalty_bindings=4")

	numerics.special_foreground_instance_cap = 1
	var stacked_profile := alien.duplicate() as LevelProfile
	stacked_profile.special_instance_screen_cap = 1
	stacked_profile.special_trait_ids = ["reflect", "fake_card"]
	var stacked_traits: Array[StringName] = [BarrageTraitSet.REFLECT, BarrageTraitSet.FAKE_CARD]
	var first: BarrageView = area.spawn_normal_barrage(stacked_profile, speech, stacked_traits)
	_expect(first != null and first.runtime_record.trait_set.get_hit_result().kind == BarrageTraitResult.Kind.REFLECT, "stacked traits use one slot and reflect priority")
	_expect(area.spawn_normal_barrage(stacked_profile, speech, stacked_traits) == null, "special cap preserved")
	_expect(area.spawn_normal_barrage(alien, speech) != null, "full special slots allow ordinary speech")
	area.clear_current_barrages()
	numerics.special_foreground_instance_cap = NUMERICS.special_foreground_instance_cap

	var runner := TutorialStepRunner.new()
	var hint = HINT.new()
	root.add_child(hint)
	hint.position = Vector2(500, 940)
	hint.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	hint.add_theme_font_size_override("font_size", 28)
	runner.hint_requested.connect(hint.show_tutorial_hint)
	runner.tutorial_completed.connect(func(_id: String) -> void: hint.clear_tutorial_hint())
	var completed_events: Array[String] = []
	runner.step_completed.connect(func(id: String) -> void: completed_events.append(id))
	_expect(runner.begin(alien.tutorial_config_id), "formal tutorial begins")
	var aim := AimReticle.new()
	root.add_child(aim)
	aim.set_process(false)
	var attack := AttackChargeInput.new()
	root.add_child(attack)
	attack.configure_target_query(aim, area)
	attack.configure_attack_timing(numerics.create_attack_timing_config())
	attack.configure_hit_resolution(HitResolution.new(0.5, 0.0, 1.0, 0.02, 0.02, numerics))
	attack.shot_hit_resolution_submitted.connect(func(snapshot: AttackTargetSnapshot, submission: Dictionary) -> void:
		runner.on_shot_resolved(snapshot, submission, 0, null))
	var target: BarrageView = area.spawn_normal_barrage(alien, speech)
	target.position = Vector2(340, 300)
	target.set_process(false)
	aim.restore_mouse_aim(target.get_global_rect().get_center())
	paused = true
	runner.observe_combat_frame(area, aim, attack)
	_expect(runner.get_active_step_id() == "tutorial_001_aim", "pause freezes tutorial observation")
	paused = false
	runner.observe_combat_frame(area, aim, attack)
	_expect(runner.get_active_step_id() == "tutorial_001_charge", "real ordinary overlap completes aim")
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = target.get_global_rect().get_center()
	attack._input(down)
	attack._process(numerics.charge_time_seconds)
	runner.observe_combat_frame(area, aim, attack)
	_expect(runner.get_active_step_id() == "tutorial_001_fire", "actual charge state completes charge")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/tmp/INT17C_tutorial_fire_2026-10-16.png")
	var repeat_submission: Dictionary = {"hit_resolution_result": {"target_results": [{"is_valid_hit": true, "is_repeat": true, "trait_result": BarrageTraitResult.new()}]}}
	runner.on_shot_resolved(null, repeat_submission, 0, null)
	_expect(runner.get_active_step_id() == "tutorial_001_fire", "repeat hit cannot complete fire")
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	attack._input(up)
	await create_timer(numerics.projectile_flight_seconds + 0.1).timeout
	_expect(runner.get_active_step_id().is_empty() and completed_events.size() == 3, "actual attack submission completes fire exactly once")
	_expect(not runner.notify_event("tutorial_normal_hit"), "duplicate completion ignored")
	var progress: Array[String] = ["tutorial_001_aim", "tutorial_001_charge"]
	_expect(runner.begin(alien.tutorial_config_id, progress), "restore unfinished fire")
	_expect(runner.get_current_hint().get("step_id", "") == "tutorial_001_fire", "restore immediately replays current hint")
	progress.append("outside_mutation")
	_expect(not runner.get_completed_step_ids().has("outside_mutation"), "progress returned as independent copy")
	print("INT17C_TUTORIAL_PASS facts=target,aim,full_charge,normal_hit completed=", completed_events)
	area.clear_current_barrages()
	attack.queue_free()
	aim.queue_free()
	hint.queue_free()
	for trait_id: StringName in [&"occlusion", &"retaliation_copy", &"fake_card", &"unselectable", &"split", &"reflect"]:
		var status: Dictionary = catalog.get_visual_asset_status(trait_id)
		if bool(status["missing_mapping"]):
			print("INT17C_ASSET_MISSING ", status["visual_asset_id"])
	if DisplayServer.get_name() != "headless":
		# 截图夹具只在内存放宽名额，以同屏呈现六类正式特性；正式配置保持不变。
		numerics.special_foreground_instance_cap = 6
		var y: float = 40.0
		for trait_id: StringName in [&"occlusion", &"retaliation_copy", &"fake_card", &"unselectable", &"split", &"reflect"]:
			for skill: Dictionary in catalog.get_enabled_skills():
				if catalog.get_skill_trait_ids(skill).has(trait_id):
					var profile: LevelProfile = profiles[str(skill["streamer_id"])]
					var view: BarrageView = runtime.spawn_skill(profile, profile.get_normal_speech_pool()[0], skill)
					if view != null:
						view.position = Vector2(60, y)
						view.set_process(false)
						y += 130.0
					break
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/tmp/INT17C_traits_2026-10-16.png")
		print("INT17C_PREVIEW D:/tmp/INT17C_traits_2026-10-16.png")
	runtime.unbind()
	area.queue_free()
	await process_frame
	print("INT17C_RUNTIME_PASS" if failures == 0 else "INT17C_RUNTIME_FAIL count=%d" % failures)
	quit(0 if failures == 0 else 1)
