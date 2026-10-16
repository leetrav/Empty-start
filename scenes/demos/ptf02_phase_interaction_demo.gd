extends Control

const CATALOG = preload("res://data/level_configuration/level_catalog.tres")
const TIERS = preload("res://data/combat_stage/tier_catalog.tres")
const CONFIG = preload("res://data/sandbox/playable_battle_config.tres")
const DECAY = preload("res://data/divine_descent/divine_descent_decay_config.tres")
const WINDOW = preload("res://systems/contradiction_break/contradiction_window_config.tres")
const CARDS = preload("res://data/loser_card/loser_card_catalog.tres")

var _area: BarrageArea
var _attack: AttackChargeInput
var _hud: Control
var _display: FinalOracleCandidateDisplay
var _flow: ContradictionOracleFlow
var _divine: DivineDescentFlow
var _run: SaveData
var _hit: HitResolution
var _stage: CombatStage
var _opponent: OpponentPKBar
var _queue: RepeatDelayQueue
var _variant_b: bool = false
var _status: Label
var _clock: float = 0.0
var _mode: String = "普通话语"
var _movie: bool = false
var _record_climax: bool = false
var _replay_inputs: bool = false
var _preview_dir: String = ""
var _input_count: int = 0
var _end_count: int = 0


# 可复播的组件预览，正式素材和流程对象保持真实；内存历史为明确演示夹具，永不写玩家存档。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_title("PTF-02 A/B · Godot真实输入预览")
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
	for arg: String in OS.get_cmdline_user_args():
		_variant_b = _variant_b or arg == "--variant-b"
		_movie = _movie or arg == "--record-sequence"
		_record_climax = _record_climax or arg == "--record-climax"
		_replay_inputs = _replay_inputs or arg == "--replay-inputs"
		if arg.begins_with("--preview-dir="):
			_preview_dir = arg.trim_prefix("--preview-dir=")
	if "--windowed-720" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	var visual := preload("res://scenes/sandbox/sandbox.tscn").instantiate()
	visual.set_script(null)
	visual.get_node("AttackChargeInput").set_script(null)
	add_child(visual)
	_area = visual.get_node("%BarrageArea")
	_area.repeat_barrage_screen_cap = CONFIG.repeat_screen_cap
	_area.process_mode = Node.PROCESS_MODE_PAUSABLE
	_hud = visual.get_node("BattleHud")
	_attack = AttackChargeInput.new()
	_attack.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_attack)
	_attack.configure_attack_timing(CONFIG.attack_timing)
	_attack.configure_target_query(visual.get_node("%AimReticle"), _area)
	_hud.bind_portrait_attack(_attack)
	_display = preload("res://ui/final_oracle/final_oracle_candidate_display.tscn").instantiate()
	add_child(_display)
	_display.position = _area.global_position
	_display.size = _area.size
	_opponent = OpponentPKBar.new()
	add_child(_opponent)
	var panel := PanelContainer.new()
	add_child(panel)
	panel.position = Vector2(470, 18)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 22)
	box.add_child(_status)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	for item: Array in [["A/B 切换 [Tab]", _switch_variant], ["普通 [1]", _normal], ["矛盾 [2]", _paradox], ["神降临 [3]", _start_divine], ["暂停 [P]", _pause]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(item[1])
		buttons.add_child(button)
	_normal()
	if _record_climax:
		_record_climax_sequence.call_deferred()
	elif _movie:
		_record_sequence.call_deferred()
	await get_tree().create_timer(0.2).timeout
	DisplayServer.window_set_title("PTF-02 B · A/B interaction preview")


# 每次复播独立内存数据；只为候选演示记录真实词库中四条非中立原句，标注为夹具。
func _reset() -> void:
	get_tree().paused = false
	if is_instance_valid(_flow):
		_flow.stop()
		_flow.queue_free()
		_flow = null
	if is_instance_valid(_divine):
		_divine.stop()
		_divine.queue_free()
		_divine = null
	_display.clear_display()
	_area.clear_barrages()
	_run = SaveData.new()
	_run.streamer_name = "PTF-02 演示夹具"
	_run.live_session.configure_formal_rules(preload("res://data/combat_stage/combat_numerics.tres"))
	_hit = HitResolution.new(0.5, 0.0, 1.0)
	var count := 0
	for speech: LevelSpeech in CATALOG.profiles[0].get_normal_speech_pool():
		if speech.tendency_id != "neutral":
			_hit.record_normal_word_hit(speech.original_sentence_id, speech.tendency_id)
			count += 1
			if count == 4:
				break
	_stage = CombatStage.new(TIERS)
	_queue = RepeatDelayQueue.new(CONFIG.maximum_pending_repeat_count)
	_clock = 0.0
	_input_count = 0
	var consumer = preload("res://data/shared/formal_sheet_runtime_consumer.gd").new()
	var presentation: Dictionary = consumer.get_level_presentation(CATALOG.profiles[0].level_id)
	var assets: PresentationAssetConfig = preload("res://data/shared/presentation_asset_config.tres")
	_hud.reset_for_attempt(5)
	_hud.configure_streamers(_run.streamer_name, CATALOG.profiles[0].streamer_name)
	_hud.configure_streamer_assets(assets.player_streamer_portrait, assets.player_live_background,
		assets.player_fan_badge, presentation["portrait_idle"], presentation["background"], null)
	_hud.configure_opponent_result(CATALOG.profiles[0], presentation)
	_hud.refresh_pk(1.0, 5)
	_hud.set_paradox_stage_active(false, 5)
	_attack.set_contradiction_mode(false)
	_attack.set_combat_active(false)


# 展示普通同源 BarrageView 运动和现有场景边框，供真人对照矛盾候选。
func _normal() -> void:
	_reset()
	_mode = "普通话语 / 同源对照"
	_area.start_normal_generation(CATALOG.profiles[0])
	var plan := RepeatPlan.create_normal_hit_plan(&"demo_repeat", "", 5, 12, CONFIG.repeat_lifetime_seconds)
	var speech: LevelSpeech = CATALOG.profiles[0].get_normal_speech_pool()[0]
	plan.original_line_id = StringName(speech.original_sentence_id)
	plan.original_line_text = speech.text
	plan.apply_display_template(CONFIG.repeat_display_template)
	_queue.enqueue_plan(plan)


# 从真实十秒候选窗口开始，左键按住蓄力并释放；没有合成击破或调试推进。
func _paradox() -> void:
	_reset()
	_mode = "矛盾 / 按住左键蓄力，松开射击（10 秒 / 一发）"
	_flow = ContradictionOracleFlow.new()
	_flow.repeat_climax_interactive = _variant_b
	_flow.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_flow)
	_flow.state_text_changed.connect(_hud.show_battle_state)
	_flow.rest_ready.connect(func(_result: RestSession) -> void:
		_mode = "Rest 已接收 · 原输入可重新选择预览"
		print("PTF02 Rest at=%.2f variant=%s" % [_clock, _variant_b]))
	_flow.oracle_opened.connect(func(_session: FinalOracleSession) -> void:
		_mode = "Oracle 三候选 / 蓄力释放确认 / 10 秒自动确认"
		print("PTF02 Oracle at=%.2f" % _clock))
	_flow.repeat_climax_finished.connect(func() -> void:
		print("PTF02 climax_finished at=%.2f requested=%s actual=%s" % [_clock,
			_queue.get_generation_stats().contradiction_requested_counts_by_line_id,
			_queue.get_generation_stats().contradiction_counts_by_line_id]))
	_flow.start(_run, CATALOG, CATALOG.profiles[0], _hit, _stage, _area, _opponent,
		_attack, _queue, _display, CONFIG, CARDS, WINDOW, get_node("/root/AudioManager"))
	_hud.set_paradox_stage_active(true, 5)


# 两版都保留 15 表自动收束；B 允许每次操作额外推进衰减并请求一次真实复读。
func _start_divine() -> void:
	_reset()
	_hit.commit_normal_hit_history(_run)
	_mode = "神降临 / A=回应，B=回应+主动推进（历史为演示夹具）"
	_divine = DivineDescentFlow.new()
	_divine.interaction_repeat_enabled = _variant_b
	_divine.interaction_decay_step_seconds = 0.8 if _variant_b else 0.0
	_divine.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_divine)
	_divine.interaction_received.connect(func(phase: StringName) -> void:
		_input_count += 1
		print("PTF02 INPUT_ACCEPTED phase=%s t=%.2f count=%d" % [phase, _clock, _input_count])
		_capture("input_%02d" % _input_count))
	_divine.completed.connect(func(result: EndingSession) -> void:
		_end_count += 1
		_mode = "EndingSession 已接收 · 单次完成 #%d" % _end_count
		print("PTF02 Ending received=%s at=%.2f input=%d" % [result.is_received(), _clock, _input_count]))
	_hud.bind_audio_flows(null, _divine)
	_divine.start(_run, CATALOG, CATALOG.profiles[0], TIERS, _hit, _stage, null,
		_area, _opponent, _attack, CONFIG, DECAY,
		{"repeat_interval_seconds": 0.0, "fade_seconds": 0.0, "hold_seconds": 0.0})


# A/B 切换只影响下次复播，避免同一演出中悄悄更换规则。
func _switch_variant() -> void:
	_variant_b = not _variant_b


# 演示自己的暂停入口；生产根暂停继续归 A。
func _pause() -> void:
	get_tree().paused = not get_tree().paused


# 和根正式入口一样逐帧推进，暂停后业务时间和生成队列均冻结。
func _process(delta: float) -> void:
	if not get_tree().paused:
		_clock += delta
		if _flow == null and _divine == null:
			_queue.advance_and_dispatch(delta, _area)
	if is_instance_valid(_flow):
		_flow.advance(delta)
	if is_instance_valid(_divine):
		_divine.advance(delta)
	_status.text = "%s · %.1fs · %s" % ["B 主动" if _variant_b else "A 自动", _clock, _mode]
	if _replay_inputs:
		_status.text += " [组件输入回放 / 真人操作待验收]"
	_hud.refresh_attack(_attack.get_charge_progress(), _attack.get_attack_phase())


# 真实窗口快捷键和鼠标/触摸输入，绝不在预览脚本合成 InputEvent。
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _normal()
			KEY_2: _paradox()
			KEY_3: _start_divine()
			KEY_TAB: _switch_variant()
			KEY_P: _pause()
	if is_instance_valid(_divine) and _divine.handle_input(event):
		get_viewport().set_input_as_handled()
	elif is_instance_valid(_flow) and _flow.handle_input(event):
		get_viewport().set_input_as_handled()


# 连续录像自动复播普通与终局；输入另用真实 Windows 事件验证，录像不声称完整玩家路线。
func _record_sequence() -> void:
	await get_tree().create_timer(3.0).timeout
	await _capture("normal")
	_start_divine()
	if _replay_inputs:
		_replay_divine_inputs()
	await get_tree().create_timer(1.0).timeout
	await _capture("birth")
	await get_tree().create_timer(5.0).timeout
	await _capture("cluster")
	await get_tree().create_timer(6.4).timeout
	await _capture("locked")
	await get_tree().create_timer(6.0).timeout
	await _capture("ending")
	get_tree().quit()


# 录像明确标注组件事件回放；真人可直接按同一 demo 的空格/点击，不把回放当硬件验收。
func _replay_divine_inputs() -> void:
	for index: int in range(8):
		await get_tree().create_timer(0.75).timeout
		if not is_instance_valid(_divine) or _divine.get_result() != null:
			return
		var event := InputEventKey.new()
		event.keycode = KEY_SPACE
		event.pressed = true
		print("PTF02 REPLAY_COMPONENT_INPUT %d" % index)
		_divine.handle_input(event)


# 两版复读录像从真实六句视图的释放快照起步；仅替代瞄准动作，后续队列与 Oracle 使用生产代码。
func _record_climax_sequence() -> void:
	await get_tree().create_timer(1.0).timeout
	_paradox()
	await get_tree().create_timer(2.1).timeout
	await _capture("paradox")
	var targets: Array[Node] = []
	for child: Node in _area.get_children():
		if child is BarrageView and child.runtime_record.original_sentence_id == CATALOG.profiles[0].true_contradictions[0].original_sentence_id:
			targets.append(child)
	_attack.shot_snapshot_created.emit(AttackTargetSnapshot.capture_at_release(targets))
	print("PTF02 FIXTURE_RELEASE true_targets=%d" % targets.size())
	await get_tree().create_timer(0.35).timeout
	await _capture("climax_birth")
	if _variant_b:
		var event := InputEventKey.new()
		event.keycode = KEY_SPACE
		event.pressed = true
		print("PTF02 REPLAY_COMPONENT_INPUT accelerate=%s" % _flow.handle_input(event))
		await get_tree().create_timer(0.25).timeout
		await _capture("climax_cluster")
		event.keycode = KEY_ENTER
		print("PTF02 REPLAY_COMPONENT_INPUT end=%s" % _flow.handle_input(event))
		await _capture("climax_accelerated")
	else:
		await get_tree().create_timer(0.55).timeout
		await _capture("climax_cluster")
	await get_tree().create_timer(5.5).timeout
	await _capture("oracle")
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


# 渲染器原始 GPU 帧只写 D 盘外部目录；不将录像充当人工视觉验收。
func _capture(label: String) -> void:
	if _preview_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_preview_dir.path_join(("b_" if _variant_b else "a_") + label + ".png"))
