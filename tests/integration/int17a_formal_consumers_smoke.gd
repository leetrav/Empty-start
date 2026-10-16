extends SceneTree

const AREA_SCENE = preload("res://systems/barrage_generation/barrage_area.tscn")
const AIM_SCENE = preload("res://systems/combat_attack/aim_reticle.tscn")
const PK_SAMPLES: Array[float] = [0.50, 0.60, 0.67, 0.75, 0.85, 0.95]
var _failures: Array[String] = []
var _submission: Dictionary = {}
var _canvas: Control
var _numerics: CombatNumericsConfig
var _tiers: CombatStageTierCatalog
var _live: LiveSessionData

class LiveTicker extends Node:
	var live: LiveSessionData
	## 使用真实帧推进直播上涨，录屏中可直接观察整数变化。
	func _process(delta: float) -> void:
		live.advance_short_boosts(delta)


## 使用 C 的公开目录协议做确定性容量测试；实际目录合入后可直接注入同一入口。
class CatalogProbe extends RefCounted:
	var draws: int = 0
	## 确定性返回不可选技能，便于复现容量占满。
	func choose_skill(_streamer: String, tier: int, _rng: RandomNumberGenerator = null) -> Dictionary:
		draws += 1
		return {"tier": tier, "trait_ids": "unselectable"}
	## 按目录公开协议返回已支持的特性 ID。
	func get_skill_trait_ids(_skill: Dictionary) -> Array[StringName]:
		return [BarrageTraitSet.UNSELECTABLE]
	## 只提供本测试涉及的寿命快照。
	func get_trait_definition(_id: StringName) -> Dictionary:
		return {"lifetime_override_s": "5"}
	## 固定5秒，验证生成器实际消费目录覆盖值。
	func get_lifetime_override(_ids: Array[StringName]) -> float:
		return 5.0


## 延迟到 SceneTree 就绪，实际运行生产 Scene 与四关 Resource。
func _initialize() -> void:
	call_deferred("_run")


## 验证四关生成、T0～T5、回拉、真实蓄力释放和正式样式。
func _run() -> void:
	seed(1716)
	root.size = Vector2i(1920, 1080)
	_canvas = Control.new()
	_canvas.size = Vector2(1920, 1080)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei"])
	_canvas.theme = Theme.new()
	_canvas.theme.default_font = font
	root.add_child(_canvas)
	_numerics = load("res://data/combat_stage/combat_numerics.tres")
	_tiers = load("res://data/combat_stage/tier_catalog.tres")
	_live = LiveSessionData.new()
	_live.configure_formal_rules(_numerics)
	_live.initialize_session(100)
	_label(Vector2(30, 12), "INT-17A · 四关生产 Resource / 真实生成与攻击组件 · 系统字体仅用于缺字体工作树验收")
	for index: int in range(4):
		await _verify_level(index)
	_verify_live_rules()
	_verify_skill_entry()
	var live_label := Label.new()
	live_label.position = Vector2(30, 1010)
	live_label.add_theme_font_size_override("font_size", 26)
	_canvas.add_child(live_label)
	_live.changed.connect(func(): live_label.text = "09 LIVE · Viewer %d / Like %d / Comment %d | failures=%d" % [_live.viewer_count, _live.like_count, _live.comment_count, _failures.size()])
	var ticker := LiveTicker.new()
	ticker.live = _live
	root.add_child(ticker)
	_live.start_formal_short_boost(LiveSessionData.BoostEvent.CONTRADICTION_BREAK)
	await create_timer(2.1).timeout
	_live.start_formal_short_boost(LiveSessionData.BoostEvent.ORACLE_CONFIRMATION)
	await create_timer(2.1).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("res://.godot/int17a/formal_four_levels.png")
		root.get_texture().get_image().save_png(path)
		print("INT17A_SCREENSHOT=" + path)
	if _failures.is_empty():
		print("INT17A_FORMAL_CONSUMERS_PASS levels=4 tiers=0..5 real_shots=4 style=normal/repeat/candidate live=deduped")
	else:
		for failure: String in _failures:
			push_error("INT17A_FAIL " + failure)
	quit(0 if _failures.is_empty() else 1)


## 单关始终读取正式数据；容量覆盖测试仅修改深复制的内存关卡。
func _verify_level(index: int) -> void:
	var level: LevelProfile = load("res://data/level_configuration/level_%03d.tres" % (index + 1))
	_check(level != null and not level.get_normal_speech_pool().is_empty(), "四关词库加载")
	if level == null or level.get_normal_speech_pool().is_empty():
		return
	var position := Vector2(30 + (index % 2) * 950, 90 + (index / 2) * 440)
	_label(position - Vector2(0, 36), "%s · %s · batch=%d / %.1fs / %.0fpx/s" % [level.level_id, level.streamer_name, level.base_batch_count, level.base_spawn_interval_seconds, level.base_move_speed_pixels_per_second])
	var area: BarrageArea = AREA_SCENE.instantiate()
	area.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	area.position = position
	area.size = Vector2(910, 400)
	_canvas.add_child(area)
	area.configure_combat_numerics(_numerics)
	area.barrage_generated.connect(func(_view: BarrageView): _live.record_generated_comments(1))
	var stage := CombatStage.new(_tiers)
	var hit := HitResolution.new(0.5, 0.0, 1.0, _numerics.positive_pk_shot_cap, _numerics.negative_pk_shot_cap, _numerics)
	stage.bind_hit_resolution(hit)
	stage.bind_barrage_area(area)
	stage.begin_combat()
	_check(area.start_normal_generation(level), "正式普通生成启动")
	_check(int(area.get_current_barrage_counts().get("normal", -1)) == 3, "05 首批实际生成3条")
	var speech: LevelSpeech = level.get_normal_speech_pool()[0]
	var pullback := OpponentPKBar.new()
	root.add_child(pullback)
	pullback.set_process(false)
	stage.bind_opponent_pk_bar(pullback)
	for tier: int in range(6):
		area.clear_barrages()
		hit.set_player_pk_for_debug(PK_SAMPLES[tier])
		_check(stage.get_current_tier() == tier, "真实Tier %d" % tier)
		_check(area.get_foreground_slot_count() == _tiers.get_tier_config(tier).foreground_slot_count, "08容量")
		var view: BarrageView = area.spawn_normal_barrage(level, speech)
		_check(view != null, "正式话语生成")
		if view != null:
			var lifetime := _numerics.get_lifetime_seconds("word_strength_%d" % speech.strength, _tiers.get_tier_config(tier).lifetime_multiplier)
			_check(view.runtime_record.lifetime_duration_msec == roundi(lifetime * 1000), "06按强度/Tier固定寿命")
			_check(view.get_theme_color("font_outline_color").is_equal_approx(_numerics.foreground_outline_color), "正式描边实际Theme")
		var before := hit.get_player_pk()
		pullback.start_pullback(hit, _numerics.base_pullback_speed_pk_per_second)
		# 对真实处理函数施加一秒游戏时间，避免墙钟与引擎时间混用。
		pullback._process(1.0)
		var expected := _numerics.base_pullback_speed_pk_per_second * _tiers.get_tier_config(tier).opponent_pullback_multiplier
		_check(absf(before - hit.get_player_pk() - expected) < 0.000001, "06/08一秒实际回拉")
		pullback.stop_pullback()
	# 用生产时序做一次真实鼠标按下、蓄满、松开、飞行和整发结算。
	area.clear_barrages()
	var target: BarrageView = area.spawn_normal_barrage(level, speech)
	if target != null:
		target.set_process(false)
		var aim: AimReticle = AIM_SCENE.instantiate()
		_canvas.add_child(aim)
		var attack := AttackChargeInput.new()
		root.add_child(attack)
		attack.configure_target_query(aim, area)
		attack.configure_combat_aim_radii(_numerics)
		_check(is_equal_approx(aim.visual_diameter, 96.0), "06视觉直径96与判定半径分离")
		attack.configure_attack_timing(_numerics.create_attack_timing_config())
		attack.configure_hit_resolution(hit)
		attack.set_combat_active(true)
		attack.shot_hit_resolution_submitted.connect(func(_snapshot: AttackTargetSnapshot, result: Dictionary): _submission = result)
		var before := hit.get_player_pk()
		_submission = {}
		await process_frame
		var point := root.get_final_transform() * (aim.get_canvas_transform() * target.get_global_rect().get_center())
		for pressed: bool in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.position = point
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			if pressed:
				await create_timer(0.85).timeout
		await create_timer(0.4).timeout
		var expected_reward := hit.calculate_normal_word_reward(speech.strength, speech.tendency_id)
		_check(not _submission.is_empty(), "真实单发提交")
		_check(absf(hit.get_player_pk() - before - float(expected_reward["pk_delta"])) < 0.000001, "06单发百分数换算")
		attack.set_combat_active(false)
		attack.queue_free()
		aim.queue_free()
	area.clear_barrages()
	# 六候选按正式战斗区尺寸验收，四宫格仅用于最终录屏展示。
	area.size = Vector2(1024, 1008)
	var candidate_config := ContradictionWindowConfig.new()
	_check(area.start_contradiction_generation(level, level.true_contradictions, level.false_contradictions, candidate_config), "正式六候选生成")
	_check(int(area.get_current_barrage_counts()["contradiction"]) == 6, "真实一真五假六候选")
	for child: Node in area.get_children():
		if child is BarrageView and (child as BarrageView).runtime_record.is_contradiction:
			_check((child as BarrageView).get_theme_color("font_outline_color").is_equal_approx(_numerics.foreground_outline_color), "候选实际正式描边")
			_check((child as BarrageView).runtime_record.lifetime_duration_msec == 10000, "六候选保持10秒")
	area.clear_barrages()
	area.size = Vector2(910, 400)
	# 05 每关显式值优先于06全局3；特殊满额保留普通生成。
	var limited: LevelProfile = level.duplicate(true)
	limited.special_instance_screen_cap = 1
	limited.special_trait_ids = [BarrageTraitSet.UNSELECTABLE]
	var special := area.spawn_normal_barrage(limited, speech, [BarrageTraitSet.UNSELECTABLE])
	_check(special != null, "特殊首实例")
	_check(area.spawn_normal_barrage(limited, speech, [BarrageTraitSet.UNSELECTABLE]) == null, "05显式特殊容量1")
	_check(area.spawn_normal_barrage(limited, speech) != null, "特殊满额普通可生成")
	if special != null:
		_check(special.runtime_record.lifetime_duration_msec == 5000, "不可选固定5秒")
		_check(not special.runtime_record.trait_set.is_selectable(), "不可选目标规则")
	var plan := RepeatPlan.new()
	plan.original_line_id = StringName(speech.original_sentence_id)
	plan.original_line_text = speech.text
	plan.lifetime_seconds = _numerics.get_lifetime_seconds("repeat", 0.4)
	var repeat_view := area.spawn_repeat_barrage(plan, true)
	_check(repeat_view != null, "真实复读生成")
	if repeat_view != null:
		_check(repeat_view.get_theme_color("font_color").is_equal_approx(_numerics.repeat_text_color), "复读实际灰色")
		_check(repeat_view.get_theme_constant("outline_size") == 0, "复读零描边")
	# 图形证据保留正式生成实例，让移动和原寿命按真实帧继续。
	area.clear_barrages()
	stage.begin_combat()
	area.start_normal_generation(level)
	pullback.queue_free()
	print("INT17A_LEVEL_PASS %s tier=0..5 shot_pk=%s" % [level.level_id, str(_submission.get("hit_resolution_result", {}).get("total_pk_delta", "missing"))])


## 09 两段上涨逐帧计数与去重，降档不误记升档观看。
func _verify_live_rules() -> void:
	var live := LiveSessionData.new()
	live.configure_formal_rules(_numerics)
	live.initialize_session(100)
	_check(not live.record_tier_transition(3, 2) and live.viewer_count == 0, "降档不+15观看")
	_check(live.record_tier_transition(2, 3) and live.viewer_count == 15, "升档+15观看")
	_check(live.start_formal_short_boost(LiveSessionData.BoostEvent.CONTRADICTION_BREAK), "击破上涨受理")
	_check(not live.start_formal_short_boost(LiveSessionData.BoostEvent.CONTRADICTION_BREAK), "击破上涨去重")
	live.advance_short_boosts(1.0)
	_check(live.viewer_count == 55 and live.like_count == 20 and live.comment_count == 1, "击破中点40/20与一次评论")
	live.advance_short_boosts(1.0)
	live.start_formal_short_boost(LiveSessionData.BoostEvent.ORACLE_CONFIRMATION)
	live.advance_short_boosts(2.0)
	_check(live.viewer_count == 135 and live.like_count == 60 and live.comment_count == 2, "两段上涨最终精确值")


## C 目录接口的独立契约回归；本分支不复制 C 的读表实现。
func _verify_skill_entry() -> void:
	var area: BarrageArea = AREA_SCENE.instantiate()
	area.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_canvas.add_child(area)
	area.size = Vector2(910, 400)
	area.hide()
	area.configure_combat_numerics(_numerics)
	area.begin_combat_attempt()
	var probe := CatalogProbe.new()
	area.configure_trait_catalog(probe)
	var level: LevelProfile = load("res://data/level_configuration/level_001.tres")
	var limited: LevelProfile = level.duplicate(true)
	limited.special_instance_screen_cap = 1
	var stage := CombatStage.new(_tiers)
	stage.bind_barrage_area(area)
	stage.begin_combat()
	area.start_normal_generation(limited)
	area.clear_barrages()
	stage.update_tier_for_pk(0.67)
	area.spawn_normal_batch_now()
	var special: BarrageView
	for child: Node in area.get_children():
		if child is BarrageView and (child as BarrageView).runtime_record.trait_set.has_trait(BarrageTraitSet.UNSELECTABLE):
			special = child
	_check(probe.draws == 1 and special != null, "08首次T2抽取进入真实批次")
	stage.update_tier_for_pk(0.60)
	stage.update_tier_for_pk(0.67)
	_check(probe.draws == 1, "降档回升保留原抽选")
	stage.update_tier_for_pk(0.75)
	area.spawn_normal_batch_now()
	_check(probe.draws == 2, "T3首次独立抽取")
	_check(int(area.get_current_barrage_counts()["normal"]) > 1, "特殊满容量普通生成保留")
	if special != null:
		_check(special.runtime_record.lifetime_duration_msec == 5000, "07覆盖寿命实际消费")
		area.end_barrage(special.get_instance_id())
	area.spawn_normal_batch_now()
	var special_count: int = 0
	for child: Node in area.get_children():
		if child is BarrageView and (child as BarrageView).runtime_record.trait_set.has_trait(BarrageTraitSet.UNSELECTABLE):
			special_count += 1
	_check(special_count == 1, "容量释放后待生成技能补入")
	area.clear_barrages()
	area.queue_free()
	print("INT17A_SKILL_INJECTION_PROBE first_entry=once pending=retained special_cap=1")


## 汇总失败，不用断言中断导致测试进程挂起。
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## 仅验收场景的说明文字，不进入正式产品界面。
func _label(position: Vector2, content: String) -> void:
	var label := Label.new()
	label.position = position
	label.text = content
	label.add_theme_font_size_override("font_size", 22)
	_canvas.add_child(label)
