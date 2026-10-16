extends Control

const CATALOG: LevelCatalog = preload("res://data/level_configuration/level_catalog.tres")
const TIERS: CombatStageTierCatalog = preload("res://data/combat_stage/tier_catalog.tres")
const CONFIG: SandboxBattleConfig = preload("res://data/sandbox/playable_battle_config.tres")
const DECAY: DivineDescentDecayConfig = preload("res://data/divine_descent/divine_descent_decay_config.tres")
const WINDOW: ContradictionWindowConfig = preload("res://systems/contradiction_break/contradiction_window_config.tres")
const CARDS: LoserCardCatalog = preload("res://data/loser_card/loser_card_catalog.tres")

var _area: BarrageArea
var _aim: AimReticle
var _attack: AttackChargeInput
var _opponent: OpponentPKBar
var _display: FinalOracleCandidateDisplay
var _flow: ContradictionOracleFlow
var _divine: DivineDescentFlow
var _run: SaveData
var _hit: HitResolution
var _stage: CombatStage
var _queue: RepeatDelayQueue
var _held_system: ContradictionBreakSystem
var _ending: EndingSession
var _ending_count: int = 0
var _failures: Array[String] = []
var _checks: int = 0
var _status: Label
var _preview_directory: String = ""
var _skip_climax: bool = false
var _config_only: bool = false
var _retry_only: bool = false
var _divine_only: bool = false
var _with_presentation: bool = false
var _visual_sandbox: Control
var _hud: Control
var _comic: ParadoxComicTransition
var _pa17_done: bool = false
var _comic_done: bool = false
var _result_release_done: bool = false
var _phase_audio_events: Dictionary = {}
var _active_seconds: float = 0.0
var _maximum_frame_delta: float = 0.0
var _repeat_times: Array[float] = []


# 单个真实组件组合场景；不实例化 Sandbox 根脚本或写入 SaveManager。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--skip-climax":
			_skip_climax = true
		if arg == "--config-only":
			_config_only = true
		if arg == "--retry-only":
			_retry_only = true
		if arg == "--divine-only":
			_divine_only = true
		if arg == "--with-presentation":
			_with_presentation = true
		if arg.begins_with("--preview-dir="):
			_preview_directory = arg.trim_prefix("--preview-dir=")
	if _with_presentation:
		if DisplayServer.get_name() != "headless":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_size(Vector2i(1920, 1080))
		get_node("/root/AudioManager").event_played.connect(
			func(event_id: StringName, _player: AudioStreamPlayer) -> void: _phase_audio_events[event_id] = true)
		# 复用正式 Sandbox 节点和 HUD，关闭根业务脚本，避免替 A 接线或写玩家存档。
		_visual_sandbox = preload("res://scenes/sandbox/sandbox.tscn").instantiate()
		_visual_sandbox.set_script(null)
		_visual_sandbox.process_mode = Node.PROCESS_MODE_PAUSABLE
		_visual_sandbox.get_node("AttackChargeInput").set_script(null)
		add_child(_visual_sandbox)
		_area = _visual_sandbox.get_node("%BarrageArea")
		_aim = _visual_sandbox.get_node("%AimReticle")
		_hud = _visual_sandbox.get_node("BattleHud")
		_comic = preload("res://systems/presentation/paradox_comic_transition.tscn").instantiate()
		add_child(_comic)
	else:
		_area = preload("res://systems/barrage_generation/barrage_area.tscn").instantiate()
		add_child(_area)
		_area.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_area.position = Vector2(300, 160)
		_area.size = Vector2(1320, 760)
		_aim = preload("res://systems/combat_attack/aim_reticle.tscn").instantiate()
		add_child(_aim)
	_area.process_mode = Node.PROCESS_MODE_PAUSABLE
	_area.repeat_barrage_screen_cap = CONFIG.repeat_screen_cap
	_attack = AttackChargeInput.new()
	add_child(_attack)
	_attack.configure_attack_timing(CONFIG.attack_timing)
	_attack.configure_target_query(_aim, _area)
	_opponent = OpponentPKBar.new()
	add_child(_opponent)
	_display = preload("res://ui/final_oracle/final_oracle_candidate_display.tscn").instantiate()
	add_child(_display)
	_display.position = _area.global_position
	_display.size = _area.size
	_status = Label.new()
	add_child(_status)
	_status.position = Vector2(100, 60)
	_status.add_theme_font_size_override("font_size", 28)
	_status.visible = not _with_presentation
	if _with_presentation:
		_hud.bind_portrait_attack(_attack)
	_run_checks.call_deferred()


# 和正式根场景一样逐帧推进 Flow；暂停由各生产入口检查。
func _process(delta: float) -> void:
	if not get_tree().paused:
		_maximum_frame_delta = maxf(_maximum_frame_delta, delta)
		_active_seconds += delta
	if is_instance_valid(_flow):
		_flow.advance(delta)
	if is_instance_valid(_divine):
		_divine.advance(delta)
	if is_instance_valid(_hud) and _status != null:
		_hud.show_battle_state(_status.text)


# 使用正式模板、容量和延时检查，然后运行四关真实 Paradox 消费者。
func _run_checks() -> void:
	if _retry_only:
		await _verify_timeout_and_retry()
		_finish()
		return
	if _divine_only:
		_hit = HitResolution.new(0.5, 0.0, 1.0)
		_stage = CombatStage.new(TIERS)
		await _verify_divine_completion()
		_finish()
		return
	var plan := RepeatPlan.create_normal_hit_plan(&"smoke", "原句保留", 0, 110, CONFIG.repeat_lifetime_seconds)
	_check(plan.apply_display_template(CONFIG.repeat_display_template) == "原句保留", "10 表原句模板")
	var queue := RepeatDelayQueue.new(CONFIG.maximum_pending_repeat_count)
	_check(queue.enqueue_plan(plan) == 96, "10 表待生成容量 96")
	var delays_valid := true
	for delay: float in plan.wait_offsets_seconds:
		delays_valid = delays_valid and delay >= 0.5 and delay <= 3.0
	_check(delays_valid, "10 表 0.5–3 秒延时")
	for level: LevelProfile in CATALOG.profiles:
		_check(_start_paradox(level), "%s 启动正式 Paradox" % level.level_id)
		_check(_views().size() == 6 and _held_system.get_remaining_shots() == 1, "11 表六句单发")
		_check(_held_system.get_remaining_seconds() > 9.8, "11 表十秒窗口")
		_check(_attack.can_start_charging(), "11 表运动时可攻击")
		var positions: Array[Vector2] = []
		var views := _views()
		for view: BarrageView in views:
			positions.append(view.position)
		await _wait(0.12)
		var moved := true
		for index: int in range(views.size()):
			moved = moved and not views[index].position.is_equal_approx(positions[index])
		_check(moved, "%s 六句真实移动" % level.level_id)
		await _wait(2.0)
		positions.clear()
		for view: BarrageView in views:
			positions.append(view.position)
		await _wait(0.12)
		var stopped := true
		for index: int in range(views.size()):
			stopped = stopped and views[index].position.is_equal_approx(positions[index])
		_check(stopped, "%s 两秒曲线减速后停止" % level.level_id)
		_flow.stop()
		_flow.queue_free()
		_flow = null
		_area.clear_barrages()
		await get_tree().process_frame
	if _config_only or not _failures.is_empty():
		_finish()
		return
	await _verify_attack_and_oracle()
	await _verify_timeout_and_retry()
	await _verify_divine_completion()
	_finish()


# 每个尝试只组合已有公开对象；历史用正式原句经 HitResolution 入口记录。
func _start_paradox(level: LevelProfile) -> bool:
	if is_instance_valid(_flow):
		_flow.stop()
		_flow.queue_free()
	_area.clear_barrages()
	_run = SaveData.new()
	_run.streamer_name = "INT-17B 组件验证"
	_run.live_session.configure_formal_rules(preload("res://data/combat_stage/combat_numerics.tres"))
	_hit = HitResolution.new(1.0, 0.0, 1.0)
	var count := 0
	for speech: LevelSpeech in level.get_normal_speech_pool():
		if speech.tendency_id != "neutral":
			_hit.record_normal_word_hit(speech.original_sentence_id, speech.tendency_id)
			count += 1
			if count == 4:
				break
	_stage = CombatStage.new(TIERS)
	_queue = RepeatDelayQueue.new(CONFIG.maximum_pending_repeat_count)
	_flow = ContradictionOracleFlow.new()
	_flow.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_flow)
	_flow.outcome_resolved.connect(_hold_result)
	_flow.state_text_changed.connect(func(text: String) -> void: _status.text = text)
	_flow.configure_oracle_parameters(10.0, 3)
	var started := _flow.start(_run, CATALOG, level, _hit, _stage, _area, _opponent,
		_attack, _queue, _display, CONFIG, CARDS, WINDOW, get_node("/root/AudioManager"))
	_held_system = _flow.get_contradiction_system()
	if _with_presentation:
		_configure_result_visuals(level)
	return started


# 在同步结果回调里持有演出，模拟 PA-17 真实完成信号交接。
func _hold_result(outcome: int) -> void:
	_check(_flow.hold_result_presentation(), "PA-17 成败结果持有")
	_held_system = _flow.get_contradiction_system()
	if _with_presentation:
		_play_result_sequence.call_deferred(outcome, _held_system)


# 正式表、HUD 及 PA-17 公开入口与 A 根场景需要的组合相同。
func _configure_result_visuals(level: LevelProfile) -> void:
	var consumer = preload("res://data/shared/formal_sheet_runtime_consumer.gd").new()
	var presentation: Dictionary = consumer.get_level_presentation(level.level_id)
	var assets: PresentationAssetConfig = preload("res://data/shared/presentation_asset_config.tres")
	_hud.reset_for_attempt(5)
	_hud.configure_streamers(_run.streamer_name, level.streamer_name)
	_hud.configure_portrait_character(str(presentation.get("streamer_id", level.streamer_id)))
	_hud.configure_streamer_assets(assets.player_streamer_portrait, assets.player_live_background,
		assets.player_fan_badge, presentation["portrait_idle"], presentation["background"], null)
	var tiers: Array = presentation["portrait_tiers"]
	_hud.configure_opponent_tier_textures(tiers[0], tiers[1], tiers[2], tiers[3])
	_check(_hud.configure_opponent_result(level, presentation), "正式 PA-17 资源配置")
	_hud.refresh_pk(1.0, 5)
	_hud.set_opponent_portrait_connected(true)
	_hud.set_paradox_stage_active(true, 5)
	_hud.bind_audio_flows(_flow)
	_pa17_done = false
	_comic_done = false
	_result_release_done = false


# 真实 PA-12 完成后才启动十秒窗口，暂停期间同样保持转场。
func _play_entry_comic() -> void:
	if not _with_presentation:
		return
	_attack.set_combat_active(false)
	_comic.play_transition()
	await _wait(0.25)
	await _capture("pa12_entry")
	get_tree().paused = true
	await _wait(0.25)
	_check(_comic.visible and not _attack.can_start_charging(), "暂停期间 PA-12 转场未开放攻击")
	get_tree().paused = false
	await _comic.transition_finished
	_check(not _comic.visible, "真实 PA-12 入场完成")


# 验收层串接正式 PA-17 和 PA-12；生产根脚本仍由 A 采用此完成顺序。
func _play_result_sequence(outcome: int, source: Variant) -> void:
	var source_flow := _flow
	var broken := outcome == ContradictionBreakSystem.Outcome.BREAKTHROUGH
	var pa17_state := {"done": false}
	_hud.opponent_result_presentation_finished.connect(
		func(_broken: bool) -> void: pa17_state["done"] = true, CONNECT_ONE_SHOT)
	_check(_hud.play_opponent_result(broken), "真实 PA-17 结果演出启动")
	await _wait(0.25)
	await _capture("pa17_%s_mid" % ("defeat" if broken else "offline"))
	get_tree().paused = true
	await _wait(2.0)
	_check(not pa17_state["done"] and source_flow.get_result() == null, "暂停 2 秒冻结 PA-17，Rest 尚未交付")
	get_tree().paused = false
	var deadline := Time.get_ticks_msec() + 6000
	while not pa17_state["done"] and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(pa17_state["done"], "真实 PA-17 完成信号")
	if not is_instance_valid(source) or source != source_flow.get_contradiction_system():
		return
	_pa17_done = true
	await _capture("pa17_%s_finished" % ("defeat" if broken else "offline"))
	var comic_state := {"done": false}
	_comic.result_feedback_finished.connect(
		func(_success: bool) -> void: comic_state["done"] = true, CONNECT_ONE_SHOT)
	_comic.play_result_feedback(broken)
	await _wait(0.15)
	await _capture("pa12_%s_result" % ("defeat" if broken else "offline"))
	get_tree().paused = true
	await _wait(1.0)
	_check(not comic_state["done"] and source_flow.get_result() == null, "暂停 1 秒冻结 PA-12 结果漫画，Rest 尚未交付")
	get_tree().paused = false
	deadline = Time.get_ticks_msec() + 3000
	while not comic_state["done"] and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(comic_state["done"] and _pa17_done, "PA-17 完成后 PA-12 才完成")
	_comic_done = true
	if is_instance_valid(source) and source == source_flow.get_contradiction_system():
		_check(source_flow.complete_result_presentation(source), "两段演出结束释放本场结果")
		_result_release_done = true


# 鼠标通过 Godot 输入管线蓄力，释放前重新跟随仍在减速运动的真实目标。
func _fire(target: Control, aim_offset: Vector2 = Vector2.ZERO) -> void:
	for pressed: bool in [true, false]:
		var point := get_viewport().get_final_transform() * (_aim.get_canvas_transform() * (target.get_global_rect().get_center() + aim_offset))
		var motion := InputEventMouseMotion.new()
		motion.position = point
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.position = point
		button.pressed = pressed
		Input.parse_input_event(button)
		Input.flush_buffered_events()
		if pressed:
			await _wait(CONFIG.attack_timing.charge_time_s + 0.05)
	await _wait(0.2)


# 真实一发、120 复读自然离场、静音、10 秒候选及正式确认写入同一会话。
func _verify_attack_and_oracle() -> void:
	await _play_entry_comic()
	_check(_start_paradox(CATALOG.profiles[0]), "攻击尝试启动")
	await get_tree().process_frame
	var target: BarrageView
	for view: BarrageView in _views():
		if view.runtime_record.original_sentence_id == CATALOG.profiles[0].true_contradictions[0].original_sentence_id:
			target = view
	if target == null:
		_check(false, "真实真矛盾目标存在")
		return
	await _capture("paradox")
	var true_id := StringName(target.runtime_record.original_sentence_id)
	# 真句上缘仍在正式 144px 判定圆内，同时避开下面紧邻的假句。
	await _fire(target, Vector2(0, -45))
	_check(_held_system.get_outcome() == ContradictionBreakSystem.Outcome.BREAKTHROUGH, "运动中释放击破")
	_check(_held_system.get_remaining_shots() == 0 and not _attack.can_start_charging(), "单发后锁住输入")
	if _held_system.get_outcome() != ContradictionBreakSystem.Outcome.BREAKTHROUGH:
		return
	print("INT17B contradiction_pending=%d" % _queue.get_pending_contradiction_count())
	var climax_start := _active_seconds
	if _skip_climax:
		var finish_event := InputEventKey.new()
		finish_event.keycode = KEY_ENTER
		finish_event.pressed = true
		get_tree().paused = true
		_check(not _flow.handle_input(finish_event), "暂停拒绝结束复读")
		get_tree().paused = false
		_check(_flow.handle_input(finish_event), "玩家可主动结束复读")
	var deadline := Time.get_ticks_msec() + 80000
	while (_queue.get_pending_contradiction_count() > 0 or _area.has_visible_contradiction_repeats()) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(_active_seconds - climax_start < 5.5, "复读非暂停等待 %.2f 秒（上限5.5）" % (_active_seconds - climax_start))
	_check(int(_queue.get_generation_stats().contradiction_requested_counts_by_line_id.get(true_id, 0)) == 120, "保留原句 120 条请求统计")
	await _wait(1.15)
	if _with_presentation:
		_check(_pa17_done and _comic_done and _result_release_done, "Oracle 前两段正式结果演出均完成")
	else:
		_check(_flow.get_oracle_session() == null, "击败动画完成前 Oracle 保持关闭")
	if _skip_climax:
		_check(_queue.get_generation_stats().get_contradiction_count(true_id) < 120, "主动结束未显示条目不冒充实际生成")
	else:
		_check(_queue.get_generation_stats().get_contradiction_count(true_id) == 120, "真实生成 120 条矛盾复读")
	if not _with_presentation:
		_flow.complete_result_presentation(_held_system)
	await get_tree().process_frame
	var oracle := _flow.get_oracle_session()
	_check(oracle != null and oracle.get_display_candidates().size() == 3, "12 表最多三个候选")
	if oracle == null:
		return
	var remaining := _flow.get_selection_timer().get_remaining_seconds()
	get_tree().paused = true
	await _wait(0.25)
	_check(is_equal_approx(remaining, _flow.get_selection_timer().get_remaining_seconds()), "暂停冻结神谕选择计时")
	get_tree().paused = false
	_check(remaining > 9.8, "12 表选择从 10 秒启动")
	await _capture("oracle")
	await _fire(_display.get_child(0) as Control)
	await get_tree().process_frame
	_check(not oracle.get_confirmed_selection().is_empty() and _flow.get_result() != null, "真实攻击确认候选并交付 Rest")
	_check(not _run.scripture_data.entries.is_empty(), "神谕正式保存经文")
	_flow.stop()
	_flow.queue_free()
	_flow = null
	_area.clear_barrages()
	await get_tree().process_frame


# 超时沿用十秒 Timer，离线完成后才交付 Rest；旧尝试完成通知须被拒绝。
func _verify_timeout_and_retry() -> void:
	await _play_entry_comic()
	_check(_start_paradox(CATALOG.profiles[1]), "超时尝试启动")
	var old_system := _held_system
	var remaining := old_system.get_remaining_seconds()
	get_tree().paused = true
	await _wait(0.25)
	_check(is_equal_approx(old_system.get_remaining_seconds(), remaining), "暂停冻结 Paradox 窗口")
	get_tree().paused = false
	await _wait(10.15)
	_check(old_system.get_outcome() == ContradictionBreakSystem.Outcome.NOT_BROKEN and _flow.get_result() == null, "超时锁定未击破并等待离线")
	if _with_presentation:
		var deadline := Time.get_ticks_msec() + 7000
		while not _result_release_done and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		_check(_pa17_done and _comic_done and _result_release_done, "离线及漫画完成才释放未击破结果")
	else:
		_check(_flow.complete_result_presentation(old_system), "离线完成释放同场结果")
	_check(_flow.get_result() != null, "未击破 Rest 接续")
	_flow.stop()
	_check(_flow.start(_run, CATALOG, CATALOG.profiles[1], _hit, _stage, _area, _opponent,
		_attack, _queue, _display, CONFIG, CARDS, WINDOW, get_node("/root/AudioManager")), "同 Flow 重试重建阶段")
	await get_tree().process_frame
	_check(not is_instance_valid(old_system), "旧矛盾实例已经真正释放")
	_check(not _flow.complete_result_presentation(old_system), "旧演出完成不能释放新尝试")
	_flow.stop()
	_flow.queue_free()
	_flow = null
	_area.clear_barrages()
	await get_tree().process_frame


# 零旧参数仍读取正式 Resource，真实 12 秒衰减后收束并收到 EndingSession。
func _verify_divine_completion() -> void:
	_run = SaveData.new()
	for speech: LevelSpeech in CATALOG.profiles[0].get_normal_speech_pool():
		if speech.tendency_id != "neutral":
			var committed_hit := HitResolution.new(0.5, 0.0, 1.0)
			committed_hit.record_normal_word_hit(speech.original_sentence_id, speech.tendency_id)
			committed_hit.commit_normal_hit_history(_run)
			break
	var saved_history_before := _run.get_committed_normal_hit_history()
	_divine = DivineDescentFlow.new()
	_divine.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_divine)
	_divine.completed.connect(func(result: EndingSession) -> void: _ending = result; _ending_count += 1)
	if _with_presentation:
		_hud.bind_audio_flows(null, _divine)
	_check(_divine.start(_run, CATALOG, CATALOG.profiles[0], TIERS, _hit, _stage, null,
		_area, _opponent, _attack, CONFIG, DECAY,
		{"repeat_interval_seconds": 0.0, "fade_seconds": 0.0, "hold_seconds": 0.0}), "15 表兜住 Sandbox 零参数并启动")
	if _divine.get_spread() == null:
		return
	_divine.get_spread().repeat_generated.connect(func(_id: StringName, _view: BarrageView, _weight: int) -> void: _repeat_times.append(_active_seconds))
	_divine.get_spread().convergence_started.connect(_on_convergence)
	await _wait(0.7)
	var press := InputEventScreenTouch.new()
	press.pressed = true
	_check(_divine.handle_input(press), "锁句前真实输入入口接受触摸")
	var progress := _divine.get_combat_mode().get_new_word_decay_progress()
	get_tree().paused = true
	await _wait(0.25)
	_check(is_equal_approx(progress, _divine.get_combat_mode().get_new_word_decay_progress()), "暂停冻结新话衰减")
	_check(not _divine.handle_input(press), "暂停拒绝神降临触摸")
	get_tree().paused = false
	var deadline := Time.get_ticks_msec() + 45000
	while _ending == null and Time.get_ticks_msec() < deadline:
		_status.text = "神降临 · 衰减 %.2f · 锁句 %s" % [_divine.get_combat_mode().get_new_word_decay_progress(), _divine.get_spread().is_sentence_locked()]
		await get_tree().process_frame
	_check(_ending != null and _ending.is_received() and _ending_count == 1, "非空历史 completed(EndingSession) 一次")
	_check(_divine.get_combat_mode().is_new_word_decay_complete(), "正式 12 秒新话衰减完成")
	_check(_run.get_committed_normal_hit_history() == saved_history_before, "输入及 Ending 显示保持已提交历史原值")
	for index: int in range(1, mini(_repeat_times.size(), 6)):
		var interval := _repeat_times[index] - _repeat_times[index - 1]
		_check(interval >= 0.14 and interval <= 0.38 + 2.0 * _maximum_frame_delta, "自动复读实际间隔 %.3f" % interval)
	await _capture("ending_received")
	_divine.stop()
	_divine.queue_free()
	_divine = null


# 记录实际全屏强调并验证暂停期间不能形成完成事实。
func _on_convergence(_candidate: Dictionary) -> void:
	await _wait(0.25)
	await _capture("divine_emphasis")
	get_tree().paused = true
	await _wait(2.0)
	_check(_ending == null, "暂停 2 秒仍未完成 1.8 秒强调 Tween")
	get_tree().paused = false


# 本场视图只通过真实区域的子节点读取。
func _views() -> Array[BarrageView]:
	var result: Array[BarrageView] = []
	for child: Node in _area.get_children():
		if child is BarrageView and not child.is_queued_for_deletion():
			result.append(child)
	return result


# 验收计时继续处理暂停中的测试节点，生产组件保持原暂停规则。
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


# 真实 GPU 画面仅写入明确提供的本地 D 盘审查目录。
func _capture(label: String) -> void:
	if _preview_directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(_preview_directory.path_join(label + ".png")) == OK, "保存实景 " + label)


# 简单断言直接输出，沿用项目 smoke 的退出码约定。
func _check(passed: bool, label: String) -> void:
	_checks += 1
	print("INT17B %s %s" % ["PASS" if passed else "FAIL", label])
	if not passed:
		_failures.append(label)


# 完成后退出临时运行，结果不写入玩家存档。
func _finish() -> void:
	if _with_presentation:
		print("INT18B_AUDIO played=%s" % str(_phase_audio_events.keys()))
	print("INT17B frame_max_delta=%.3f" % _maximum_frame_delta)
	print("INT17B_RESULT checks=%d failures=%d" % [_checks, _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)
