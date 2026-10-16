extends SceneTree

const BREAK_SYSTEM_SCRIPT = preload("res://systems/contradiction_break/contradiction_break_system.gd")
const WINDOW_CONFIG = preload("res://systems/contradiction_break/contradiction_window_config.tres")
const FORMAL_LEVEL = preload("res://data/level_configuration/level_001.tres")
const TEST_LEVEL = preload("res://tests/fixtures/contradiction_break/test_cb_13_six_candidates_level.tres")
const BARRAGE_AREA_SCENE = preload("res://systems/barrage_generation/barrage_area.tscn")
const AIM_RETICLE_SCENE = preload("res://systems/combat_attack/aim_reticle.tscn")

var _failed: int = 0
var _assertions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_formal_profile_candidates()
	var test_system: ContradictionBreakSystem = _make_loaded_system(TEST_LEVEL)
	var test_candidates: Array[LevelContradiction] = test_system.get_fixed_paradox_candidates()
	_test_test_only_candidates(test_candidates, test_system)
	_test_shot_window_and_results(test_candidates)
	await _test_barrage_area_initial_set(test_candidates)
	if _failed > 0:
		push_error("CB-13: %d assertions failed out of %d" % [_failed, _assertions])
		quit(1)
		return
	print("CB-13/CB-14: %d assertions passed" % _assertions)
	quit(0)


func _test_formal_profile_candidates() -> void:
	var system: ContradictionBreakSystem = _make_loaded_system(FORMAL_LEVEL)
	var candidates: Array[LevelContradiction] = system.get_fixed_paradox_candidates()
	_expect(FORMAL_LEVEL.true_contradictions.size() == 1, "formal sample contains one true source line")
	_expect(FORMAL_LEVEL.false_contradictions.size() == 5, "formal sample contains five enabled false source lines")
	_expect(candidates.size() == ContradictionWindowConfig.PARADOX_CANDIDATE_COUNT, "formal source builds six fixed candidates")
	_expect(_count_candidate_types(candidates, system.get_true_contradictions(), system.get_false_contradictions()) == Vector2i(1, 5), "formal source candidates classify as one true and five false")
	var source_false_ids: Dictionary = _ids_from_lines(system.get_false_contradictions())
	var selected_false_ids: Dictionary = {}
	for line: LevelContradiction in candidates:
		if source_false_ids.has(line.original_sentence_id):
			selected_false_ids[line.original_sentence_id] = true
	_expect(selected_false_ids.size() == 5, "formal candidates preserve five distinct source false IDs")
	system.queue_free()


func _test_test_only_candidates(candidates: Array[LevelContradiction], system: ContradictionBreakSystem) -> void:
	_expect(candidates.size() == ContradictionWindowConfig.PARADOX_CANDIDATE_COUNT, "TEST_ONLY profile builds six candidates")
	_expect(_count_candidate_types(candidates, system.get_true_contradictions(), system.get_false_contradictions()) == Vector2i(1, 5), "TEST_ONLY profile builds one true and five false")
	var candidate_ids: Dictionary = _ids_from_lines(candidates)
	_expect(candidate_ids.size() == ContradictionWindowConfig.PARADOX_CANDIDATE_COUNT, "TEST_ONLY fixture proves six distinct shootable IDs")
	_expect(candidate_ids.has("test_cb13_contradiction_true_001"), "TEST_ONLY fixture uses test-prefixed true ID")
	for index: int in range(1, 6):
		_expect(candidate_ids.has("test_cb13_contradiction_false_%03d" % index), "TEST_ONLY fixture includes false ID %03d" % index)


func _test_shot_window_and_results(candidates: Array[LevelContradiction]) -> void:
	_expect(is_equal_approx(WINDOW_CONFIG.duration_seconds, 10.0), "formal Paradox window remains ten seconds")
	_expect(WINDOW_CONFIG.max_shots == 1, "formal Paradox window remains one shot")
	var false_id: String = candidates[1].original_sentence_id
	var true_id: String = candidates[0].original_sentence_id
	var false_system: ContradictionBreakSystem = _make_loaded_system(TEST_LEVEL)
	var window_config: ContradictionWindowConfig = WINDOW_CONFIG.duplicate(true) as ContradictionWindowConfig
	_expect(false_system.start_window(window_config), "ten-second window starts")
	_expect(false_system.get_remaining_seconds() > 9.0, "window timer starts near ten seconds")
	_expect(false_system.register_launched_shot(), "first formal shot is accepted")
	_expect(not false_system.register_launched_shot(), "second formal shot is rejected")
	_expect(false_system.resolve_shot_hit_ids([false_id]), "one false hit fact resolves")
	_expect(false_system.get_outcome() == ContradictionBreakSystem.Outcome.NOT_BROKEN, "false-only hit keeps the existing unbroken outcome")
	false_system.queue_free()

	var true_system: ContradictionBreakSystem = _make_loaded_system(TEST_LEVEL)
	_expect(true_system.start_window(WINDOW_CONFIG.duplicate(true) as ContradictionWindowConfig), "breakthrough window starts")
	_expect(true_system.register_launched_shot(), "breakthrough shot is accepted")
	_expect(true_system.resolve_shot_hit_ids([true_id]), "one true hit fact resolves")
	_expect(true_system.get_outcome() == ContradictionBreakSystem.Outcome.BREAKTHROUGH, "true hit keeps the existing breakthrough outcome")
	true_system.queue_free()


func _test_barrage_area_initial_set(candidates: Array[LevelContradiction]) -> void:
	var area: BarrageArea = BARRAGE_AREA_SCENE.instantiate() as BarrageArea
	var title := Label.new()
	title.text = "T6 / Paradox：1 真 + 5 假（TEST_ONLY 画面验收）"
	title.position = Vector2(32.0, 16.0)
	title.add_theme_font_size_override("font_size", 28)
	root.add_child(title)
	area.set_anchors_preset(Control.PRESET_TOP_LEFT)
	area.position = Vector2(64.0, 52.0)
	area.size = Vector2(1024.0, 1008.0)
	root.add_child(area)
	var aim_reticle: AimReticle = AIM_RETICLE_SCENE.instantiate() as AimReticle
	root.add_child(aim_reticle)
	await process_frame
	# 仅在运行时副本注入正速度，保留 TEST_ONLY 关卡资源原值。
	var motion_level: LevelProfile = TEST_LEVEL.duplicate(true) as LevelProfile
	motion_level.base_move_speed_pixels_per_second = 100.0
	var config: ContradictionWindowConfig = WINDOW_CONFIG.duplicate(true) as ContradictionWindowConfig
	config.ease_out_motion_duration_seconds = 0.5
	# 速度倍率随归一化时间下降，避免演出退化成匀速移动。
	_expect(config.ease_out_motion_speed_curve.sample(0.25)
		> config.ease_out_motion_speed_curve.sample(0.5)
		and config.ease_out_motion_speed_curve.sample(0.5)
		> config.ease_out_motion_speed_curve.sample(0.75), "editable speed curve decreases during the motion")
	var invalid_false_lines: Array[LevelContradiction] = []
	for index: int in range(1, candidates.size()):
		invalid_false_lines.append(candidates[index])
	invalid_false_lines.append(candidates[1])
	_expect(not area.start_contradiction_generation(TEST_LEVEL, [], invalid_false_lines, config), "BarrageArea rejects an invalid true/false split")
	var true_lines: Array[LevelContradiction] = [candidates[0]]
	var false_lines: Array[LevelContradiction] = []
	for index: int in range(1, candidates.size()):
		false_lines.append(candidates[index])
	_expect(area.start_contradiction_generation(motion_level, true_lines, false_lines, config), "BarrageArea accepts the fixed candidate set")
	await process_frame
	var counts: Dictionary = area.get_current_barrage_counts()
	_expect(int(counts.get("contradiction", 0)) == 6, "six contradiction views appear in the initial set")
	_expect(int(counts.get("normal", 0)) == 0 and int(counts.get("repeat", 0)) == 0, "initial set occupies only the contradiction category")
	_expect(_count_visible_types(area, candidates) == Vector2i(1, 5), "visible shootable views preserve the one-plus-five source set")
	var shot_candidates: Array[Node] = []
	for child in area.get_children():
		if child is BarrageView and not child.is_queued_for_deletion():
			shot_candidates.append(child)
	var release_snapshot: AttackTargetSnapshot = AttackTargetSnapshot.capture_at_release(shot_candidates)
	var contradiction_facts: Array[Dictionary] = release_snapshot.get_contradiction_facts()
	var true_fact_count: int = 0
	var false_fact_count: int = 0
	var false_ids: Dictionary = _ids_from_lines(candidates.slice(1))
	for fact: Dictionary in contradiction_facts:
		var sentence_id: String = str(fact.get("original_sentence_id", ""))
		if sentence_id == candidates[0].original_sentence_id:
			true_fact_count += 1
		elif false_ids.has(sentence_id):
			false_fact_count += 1
	_expect(release_snapshot.get_target_instance_ids().size() == 6 and contradiction_facts.size() == 6 and true_fact_count == 1 and false_fact_count == 5, "one release snapshot freezes six shootable true/false facts")
	var initial_target: BarrageView = shot_candidates[0] as BarrageView
	aim_reticle.global_position = initial_target.get_global_rect().get_center() - aim_reticle.size * 0.5
	_expect(aim_reticle.intersects_target_area(initial_target.get_global_rect()), "a newly appeared contradiction is immediately targetable")
	var initial_positions: Dictionary = {}
	for view_node: Node in shot_candidates:
		var view: BarrageView = view_node as BarrageView
		initial_positions[view.get_instance_id()] = view.position
	await create_timer(0.12).timeout
	var moving_candidates: Array[Node] = []
	var moved_view_count: int = 0
	for child: Node in area.get_children():
		if not child is BarrageView or child.is_queued_for_deletion():
			continue
		var view: BarrageView = child as BarrageView
		moving_candidates.append(view)
		var spawn_position: Vector2 = initial_positions.get(view.get_instance_id(), view.position)
		if not view.position.is_equal_approx(spawn_position):
			moved_view_count += 1
	var moving_snapshot: AttackTargetSnapshot = AttackTargetSnapshot.capture_at_release(moving_candidates)
	var moving_target: BarrageView = moving_candidates[0] as BarrageView
	aim_reticle.global_position = moving_target.get_global_rect().get_center() - aim_reticle.size * 0.5
	_expect(moved_view_count == 6, "all six contradiction views move from spawn positions")
	_expect(aim_reticle.intersects_target_area(moving_target.get_global_rect()), "a moving contradiction remains inside the existing reticle hit query")
	_expect(moving_snapshot.get_contradiction_facts().size() == 6, "release snapshot captures all six while they move")
	await create_timer(config.ease_out_motion_duration_seconds + 0.15).timeout
	var stopped_positions: Dictionary = {}
	var stopped_candidates: Array[Node] = []
	for child: Node in area.get_children():
		if child is BarrageView and not child.is_queued_for_deletion():
			var view: BarrageView = child as BarrageView
			stopped_positions[view.get_instance_id()] = view.position
			stopped_candidates.append(view)
	await create_timer(0.12).timeout
	var stable_view_count: int = 0
	for child: Node in area.get_children():
		if not child is BarrageView or child.is_queued_for_deletion():
			continue
		var view: BarrageView = child as BarrageView
		var stopped_position: Vector2 = stopped_positions.get(view.get_instance_id(), view.position)
		if view.position.is_equal_approx(stopped_position):
			stable_view_count += 1
	var stopped_target: BarrageView = stopped_candidates[0] as BarrageView
	aim_reticle.global_position = stopped_target.get_global_rect().get_center() - aim_reticle.size * 0.5
	var stopped_snapshot: AttackTargetSnapshot = AttackTargetSnapshot.capture_at_release(stopped_candidates)
	_expect(stable_view_count == 6, "all six contradiction views stay at their eased stop positions")
	_expect(aim_reticle.intersects_target_area(stopped_target.get_global_rect()), "a stopped contradiction remains inside the existing reticle hit query")
	_expect(stopped_snapshot.get_contradiction_facts().size() == 6, "release snapshot still captures all six after motion stops")
	counts = area.get_current_barrage_counts()
	_expect(int(counts.get("contradiction", 0)) == 6, "no recurring batches replace or add to the fixed set")
	_expect(area.spawn_contradiction_barrage(motion_level, candidates[1]) == null, "the completed fixed set cannot be topped up")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot_path: String = ProjectSettings.globalize_path("res://docs/12. ContradictionBreak/evidence/CB-13/paradox-six.png")
		var screenshot_error: Error = root.get_texture().get_image().save_png(screenshot_path)
		_expect(screenshot_error == OK, "GUI screenshot is saved to the CB-13 evidence folder")
		print("CB-13 SCREENSHOT: docs/12. ContradictionBreak/evidence/CB-13/paradox-six.png")
	area.clear_barrages()
	area.queue_free()
	aim_reticle.queue_free()


func _make_loaded_system(level_profile: LevelProfile) -> ContradictionBreakSystem:
	var system: ContradictionBreakSystem = BREAK_SYSTEM_SCRIPT.new()
	root.add_child(system)
	_expect(system.load_level_content(level_profile), "ContradictionBreakSystem accepts the LevelProfile")
	return system


func _count_candidate_types(candidates: Array[LevelContradiction], true_lines: Array[LevelContradiction], false_lines: Array[LevelContradiction]) -> Vector2i:
	var true_ids: Dictionary = _ids_from_lines(true_lines)
	var false_ids: Dictionary = _ids_from_lines(false_lines)
	var true_count: int = 0
	var false_count: int = 0
	for line: LevelContradiction in candidates:
		if true_ids.has(line.original_sentence_id):
			true_count += 1
		elif false_ids.has(line.original_sentence_id):
			false_count += 1
	return Vector2i(true_count, false_count)


func _count_visible_types(area: BarrageArea, candidates: Array[LevelContradiction]) -> Vector2i:
	var true_ids: Dictionary = _ids_from_lines([candidates[0]])
	var false_ids: Dictionary = _ids_from_lines(candidates.slice(1))
	var true_count: int = 0
	var false_count: int = 0
	for record: BarrageRuntimeRecord in area.get_visible_barrage_records():
		if true_ids.has(record.original_sentence_id):
			true_count += 1
		elif false_ids.has(record.original_sentence_id):
			false_count += 1
	return Vector2i(true_count, false_count)


func _ids_from_lines(lines: Array[LevelContradiction]) -> Dictionary:
	var ids: Dictionary = {}
	for line: LevelContradiction in lines:
		ids[line.original_sentence_id] = true
	return ids


func _expect(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: " + description)
		return
	_failed += 1
	push_error("FAIL: " + description)
