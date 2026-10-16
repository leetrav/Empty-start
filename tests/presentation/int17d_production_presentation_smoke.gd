## 用正式 Sandbox/关卡/CB 结果重播表现；根场景接线示例只存在于本验收入口。
extends Control

const SANDBOX = preload("res://scenes/sandbox/sandbox.tscn")
const Consumer = preload("res://data/shared/formal_sheet_runtime_consumer.gd")
var _sandbox: Control
var _hud: Control
var _flow: ContradictionOracleFlow
var _result_done: bool = false
var _failed: bool = false
var _output: String = ""
var _played: Dictionary = {}
var _tutorial_runner_path: String = ""
var _production_played: Dictionary = {}
var _audition_finished: bool = false
var _int18d: bool = false
var _comic_done: bool = false
var _production_recorder: AudioEffectRecord
var _divine_preview: DivineDescentFlow
var _mapped_audio_ids: Array[StringName] = []


# 媒体必须写入调用者提供的 D 盘本机目录；无参数时只运行检查。
func _ready() -> void:
	# 无边框恢复完整客户区，避免 Windows 标题栏把 1080 裁成 1055。
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	get_window().size = Vector2i(1920, 1080)
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--int18d":
			_int18d = true
		if argument == "--preview-small":
			get_window().size = Vector2i(1280, 720)
			get_window().content_scale_size = Vector2i(1280, 720)
		if argument.begins_with("--int17d-runner="):
			_tutorial_runner_path = argument.trim_prefix("--int17d-runner=")
		if argument.begins_with("--int17d-output="):
			_output = argument.trim_prefix("--int17d-output=")
	if not _output.is_empty() and _output.replace("\\", "/").to_lower().begins_with("d:/"):
		DirAccess.make_dir_recursive_absolute(_output)
	else:
		_output = ""
	AudioManager.event_played.connect(_on_audio_played)
	call_deferred("_run")


# 与根组合方相同，按游戏帧推进 19 的正式衰减配置。
func _process(delta: float) -> void:
	if is_instance_valid(_divine_preview):
		_divine_preview.advance(delta)


# 先证明所有已映射资源真正进入播放器；这段是试听，不冒充 23 个生产触发都已接线。
func _run() -> void:
	var consumer = Consumer.new()
	# 原生总线录音保存真实混音，替代长时间逐帧视频编码。
	var recorder: AudioEffectRecord
	if not _output.is_empty():
		recorder = AudioEffectRecord.new()
		AudioServer.add_bus_effect(0, recorder)
		recorder.set_recording_active(true)
	var file := FileAccess.open(Consumer.TABLES["audio"], FileAccess.READ)
	var headers := file.get_csv_line()
	while not file.eof_reached():
		var values := file.get_csv_line()
		if values.size() != headers.size() or values[headers.find("asset_path_or_id")].is_empty():
			continue
		var event_id := StringName(values[headers.find("event_id")])
		_mapped_audio_ids.append(event_id)
		var event: AudioEvent = AudioManager.get("_audio_config").find_event(event_id)
		_check(event != null and event.stream != null, "early audio registered: %s" % event_id)
		AudioManager.play_event(event_id)
		await get_tree().create_timer(0.22).timeout
	_check(_played.size() == 23, "23 mapped audio events reached playing players")
	if recorder != null:
		recorder.set_recording_active(false)
		var recording: AudioStreamWAV = recorder.get_recording()
		_check(recording != null and recording.save_to_wav(_output.path_join("formal-audio-audition.wav")) == OK, "real Master bus recording saved")
		AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	# 通过正式 UI 按钮绑定入口验证菜单/身份阶段无需先进入 Sandbox 注册。
	for event_id: StringName in [&"ui_click", &"ui_name_confirm", &"ui_identity_switch", &"ui_identity_confirm", &"ui_error"]:
		var button := Button.new()
		add_child(button)
		_check(AudioManager.bind_ui_button(button, event_id), "UI button binding: %s" % event_id)
		button.pressed.emit()
		button.queue_free()
	_audition_finished = true
	if _int18d:
		_production_recorder = AudioEffectRecord.new()
		AudioServer.add_bus_effect(0, _production_recorder)
		_production_recorder.set_recording_active(true)
		await _verify_ui_audio()
	for level_number: int in [1, 2, 3, 4]:
		await _run_level(level_number, true, consumer)
	await _run_level(4, false, consumer)
	if _production_recorder != null:
		_production_recorder.set_recording_active(false)
		if not _output.is_empty():
			_production_recorder.get_recording().save_to_wav(_output.path_join("production-events.wav"))
		AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	print("INT18D ACTUAL EVENT IDS: %s" % [str(_production_played.keys())])
	if _int18d:
		for event_id: StringName in _mapped_audio_ids:
			_check(_production_played.has(event_id), "actual production source covered: %s" % event_id)
	print("INT17D RESULT failed=%s audio_played=%d; input=debug PK + real CB register/resolve; physical input=NOT TESTED" % [_failed, _played.size()])
	get_tree().quit(1 if _failed else 0)


# 每关实例化完整原 Sandbox；验收层补上交付给 INT-16 的最小调用顺序。
func _run_level(number: int, broken: bool, consumer: RefCounted) -> void:
	SaveManager.new_game()
	var profile: LevelProfile = load("res://data/level_configuration/level_%03d.tres" % number)
	var catalog := LevelCatalog.new()
	catalog.profiles = [profile]
	_sandbox = SANDBOX.instantiate() as Control
	_sandbox.set("level_catalog", catalog)
	add_child(_sandbox)
	await get_tree().process_frame
	_hud = _sandbox.get_node("BattleHud")
	_flow = _sandbox.get("_contradiction_oracle_flow") as ContradictionOracleFlow
	_check(_hud.configure_opponent_result(profile, consumer.get_level_presentation(profile.level_id)), "configure formal PA17 level %d" % number)
	_hud.bind_audio_flows(_flow)
	# 替换测试实例的结果处理顺序；正式根脚本没有修改，接线代码交由 INT-16 采用。
	_flow.outcome_resolved.disconnect(Callable(_sandbox, "_on_contradiction_outcome_resolved"))
	_flow.outcome_resolved.connect(_on_outcome)
	_hud.opponent_result_presentation_finished.connect(_on_result_finished)
	_comic_done = false
	(_sandbox.get("_paradox_comic") as ParadoxComicTransition).result_feedback_finished.connect(func(_broken: bool) -> void: _comic_done = true)
	var area: BarrageArea = _sandbox.get_node("%BarrageArea")
	# 暂停业务生成以隔离评论显示计数；随后恢复同一真实生成器。
	area.stop_normal_generation()
	var before_count: int = SaveManager.data.live_session.comment_count
	await get_tree().create_timer(4.6).timeout
	var comments: Node = _sandbox.get_node("%LiveDataHud").get("_comment_list")
	_check(comments.get_child_count() > 0, "formal comments visible level %d" % number)
	_check(SaveManager.data.live_session.comment_count == before_count, "display feed adds zero business comments")
	var paused_count: int = comments.get_child_count()
	var timer_before: float = _sandbox.get_node("%LiveDataHud").get("_comment_timer")
	var business_before_pause: int = SaveManager.data.live_session.comment_count
	get_tree().paused = true
	await get_tree().create_timer(0.3, true).timeout
	_check(comments.get_child_count() == paused_count and is_equal_approx(timer_before, float(_sandbox.get_node("%LiveDataHud").get("_comment_timer"))), "comments pause with game")
	_check(SaveManager.data.live_session.comment_count == business_before_pause, "paused display does not add business comments")
	get_tree().paused = false
	area.resume_normal_generation()
	print("INT17D COMMENT level=%d generated_business_delta=%d display_rows=%d" % [number, business_before_pause - before_count, paused_count])
	if number == 1 and broken:
		await _verify_attack(profile)
		if _int18d:
			await _verify_trait_audio(profile)
		await _show_tutorial(consumer)
	elif _int18d and broken:
		# PK 胜利前实际命中普通话语，避免构造空历史神谕分支。
		await _verify_attack(profile)
	# 保留真实 Tier 消费和箭头/CRT 过程，再跳到 PK 满进入原 PA-12 转场。
	if _int18d:
		for pk: float in [0.57, 0.65, 0.72, 0.80, 0.96]:
			_sandbox.call("debug_set_player_pk", pk)
			await get_tree().create_timer(0.46).timeout
			await _capture("level%d_tier%d" % [number, (_sandbox.get("_battle_attempt_flow") as BattleAttemptFlow).get_current_tier()])
		# 动画中重置，检查遮罩/材质/前景不会残留在下一场。
		if number != 3:
			_hud.play_opponent_result(true)
		await get_tree().create_timer(0.1).timeout
		_hud.reset_for_attempt()
		_check(not (_hud.get("_opponent_breakthrough") as Control).visible, "reset hides PA17 overlay")
		_check((_hud.get_node("%OpponentPortraitArt") as TextureRect).material == null, "reset restores portrait material")
		_check(not (_hud.get("_opponent_live_foreground") as TextureRect).visible, "reset clears opponent foreground")
		_hud.configure_opponent_result(profile, consumer.get_level_presentation(profile.level_id))
	_sandbox.call("debug_set_player_pk", 0.96)
	await get_tree().create_timer(0.8).timeout
	await _capture("level%d_t5" % number)
	if number == 1 and broken:
		await _verify_idle(consumer)
	_sandbox.call("debug_set_player_pk", 1.0)
	var deadline: int = Time.get_ticks_msec() + 18000
	while not _flow.is_contradiction_active() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not _flow.is_contradiction_active():
		_check(false, "real CB entered level %d" % number)
		_sandbox.queue_free()
		await get_tree().process_frame
		return
	_result_done = false
	_comic_done = false
	var system: ContradictionBreakSystem = _flow.get_contradiction_system()
	if broken:
		_check(system.register_launched_shot(), "CB accepts real shot")
		var ids: Array[String] = [system.get_true_contradictions()[0].original_sentence_id]
		_check(system.resolve_shot_hit_ids(ids), "CB true ID resolves breakthrough")
	else:
		while not system.is_result_locked() and system.can_launch_shot():
			system.register_launched_shot()
			var empty_ids: Array[String] = []
			system.resolve_shot_hit_ids(empty_ids)
	await get_tree().create_timer(0.5).timeout
	await _capture("level%d_%s_mid" % [number, "defeat" if broken else "offline"])
	deadline = Time.get_ticks_msec() + 6000
	while not _result_done and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(_result_done, "PA17 completion before continuation level %d broken=%s" % [number, broken])
	await _capture("level%d_%s_done" % [number, "defeat" if broken else "offline"])
	if _int18d:
		deadline = Time.get_ticks_msec() + 4000
		while not _comic_done and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		_check(_comic_done, "PA12 result comic completes after PA17")
		if number == 1 and broken:
			await _verify_final_phase_audio(profile, catalog)
	_sandbox.queue_free()
	await get_tree().process_frame


# 实际结果到达时先持有既有流程，完成后才请求原有 PA-12 漫画与后续。
func _on_outcome(outcome: int) -> void:
	# 未击破 Rest 会同步到达，根场景必须先开启既有暂存再播放局部演出。
	_sandbox.set("_result_feedback_active", true)
	_flow.hold_oracle_for_result_feedback()
	_check(_hud.play_opponent_result(outcome == ContradictionBreakSystem.Outcome.BREAKTHROUGH), "PA17 starts from true outcome")


# 复用原结果漫画，神谕释放仍由原根场景的漫画完成处理负责。
func _on_result_finished(broken: bool) -> void:
	_result_done = true
	print("INT17D PA17 COMPLETED broken=%s" % broken)
	# 留一帧击败图供截图，再启动现有结果漫画。
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(_sandbox):
		var comic: ParadoxComicTransition = _sandbox.get("_paradox_comic") as ParadoxComicTransition
		comic.play_result_feedback(broken)
		if _int18d:
			await get_tree().create_timer(0.2).timeout
			await _capture("pa12_result_%s" % ("success" if broken else "offline"))


# 仅渲染正式表中三条文案；C 运行器绑定另通过外部真实脚本验收。
func _show_tutorial(_consumer: RefCounted) -> void:
	if _int18d:
		_tutorial_runner_path = "res://systems/barrage_traits/tutorial_step_runner.gd"
	if not _tutorial_runner_path.is_empty():
		# 直接加载 C 已交付脚本，避免在本 Lane 复制步骤裁决代码。
		var runner_script: Script = load(_tutorial_runner_path) as Script
		var runner: RefCounted = runner_script.new()
		_check(_hud.bind_tutorial_runner(runner), "bind C real tutorial runner")
		_check(runner.begin("tutorial_level_001"), "C runner starts formal tutorial")
		for event_id: String in ["tutorial_target_available", "tutorial_aim_acquired", "tutorial_charge_full"]:
			runner.notify_event(event_id)
			_check(_hud.get("_tutorial_hint").visible, "C hint signal visible: " + event_id)
			await _capture(event_id)
			await get_tree().create_timer(0.3).timeout
		runner.notify_event("tutorial_normal_hit")
		_check(not _hud.get("_tutorial_hint").visible, "C tutorial completed hides hint")
		_hud.bind_tutorial_runner(null)
		return
	var file := FileAccess.open("res://data/source_tables/24_新手教学配置.csv", FileAccess.READ)
	var headers := file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() != headers.size() or row[headers.find("enabled")] != "true":
			continue
		var view: PanelContainer = _hud.get("_tutorial_hint")
		view.show_hint(row[headers.find("step_id")], row[headers.find("hint_text")])
		await _capture(row[headers.find("step_id")])
		await get_tree().create_timer(0.3).timeout
	_hud.get("_tutorial_hint").clear_hint()


# 播放完成事件包含实际播放器；音量音高与正式配置逐项对照。
func _on_audio_played(event_id: StringName, player: AudioStreamPlayer) -> void:
	var event: AudioEvent = AudioManager.get("_audio_config").find_event(event_id)
	_check(player.playing and is_equal_approx(player.volume_db, event.volume_db) and player.pitch_scale >= event.pitch_min and player.pitch_scale <= event.pitch_max, "playing audio parameters: %s" % event_id)
	_played[event_id] = true
	if _audition_finished:
		_production_played[event_id] = true


# 使用正式输入/蓄力/到达/结算，验证攻击声音通过真实消费者发出。
func _verify_attack(profile: LevelProfile) -> void:
	var battle: BattleAttemptFlow = _sandbox.get("_battle_attempt_flow") as BattleAttemptFlow
	var area: BarrageArea = battle.get_barrage_area()
	var attack: AttackChargeInput = battle.get_attack_input()
	var aim: AimReticle = battle.get_aim_reticle()
	area.stop_normal_generation()
	area.clear_current_barrages()
	var empty_traits: Array[StringName] = []
	var speech: LevelSpeech = profile.get_normal_speech_pool()[0]
	if _int18d:
		for candidate: LevelSpeech in profile.get_normal_speech_pool():
			if candidate.tendency_id != "neutral" and candidate.strength >= speech.strength:
				speech = candidate
	var view: BarrageView = area.spawn_normal_barrage(profile, speech, empty_traits, true)
	_check(view != null, "real normal target created for audio input smoke")
	if view == null:
		return
	await get_tree().process_frame
	view.position = area.size * 0.5 - view.size * 0.5
	if _int18d:
		# 使用同一正式原句生成真实多目标，达到 06 表正收益上限；不改结算输入。
		var numerics: CombatNumericsConfig = preload("res://data/combat_stage/combat_numerics.tres")
		var gain: float = numerics.normal_hit_pk_by_strength[clampi(int(speech.strength), 1, 3)]
		for _index: int in range(1, ceili(numerics.positive_pk_shot_cap / gain)):
			var extra: BarrageView = area.spawn_normal_barrage(profile, speech, empty_traits, true)
			if extra != null:
				extra.position = view.position
	var center: Vector2 = view.get_global_rect().get_center()
	var window_position: Vector2 = get_viewport().get_final_transform() * (aim.get_canvas_transform() * center)
	var motion := InputEventMouseMotion.new()
	motion.position = window_position
	motion.global_position = window_position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	for pressed: bool in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.position = window_position
		button.global_position = window_position
		Input.parse_input_event(button)
		Input.flush_buffered_events()
		if pressed:
			var deadline: int = Time.get_ticks_msec() + 3000
			while not attack.is_fully_charged() and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
			# 留一帧让音效消费者看到正式满蓄上升沿。
			await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	for event_id: StringName in [&"attack_charge", &"attack_ready", &"attack_fire", &"hit_normal"]:
		_check(_production_played.has(event_id), "real input/resolution played: %s" % event_id)
	if _int18d:
		_check(_production_played.has(&"pk_push_big"), "real capped positive shot played pk_push_big")
	await _capture("real_attack_hit")
	area.resume_normal_generation()


# 实例化生产菜单、身份和漫画；只进行可逆界面操作，避免保存或顶层路由。
func _verify_ui_audio() -> void:
	var menu: Control = preload("res://ui/main_menu/main_menu.tscn").instantiate()
	add_child(menu)
	menu.get_node("%SettingsButton").pressed.emit()
	await _capture("menu_settings_audio")
	menu.queue_free()
	await get_tree().process_frame
	SaveManager.new_game()
	var identity: Control = preload("res://ui/identity_setup/identity_setup.tscn").instantiate()
	add_child(identity)
	identity.get("_streamer_continue").pressed.emit()
	identity.complete_player_presentation()
	var selection: Control = identity.get_node("IdentitySelection")
	selection.get_node("%NextButton").pressed.emit()
	var card: Button = selection.get("_buttons")[0]
	card.pressed.emit()
	card.pressed.emit()
	await _capture("identity_selection_audio")
	selection.get_node("%NextButton").pressed.emit()
	identity.queue_free()
	await get_tree().process_frame
	var comic: Control = preload("res://ui/comic/comic_player.tscn").instantiate()
	add_child(comic)
	await get_tree().create_timer(0.25).timeout
	for _index: int in range(mini(8, comic.get("_sequence").frames.size() - 1)):
		comic.advance()
		await get_tree().create_timer(0.15).timeout
		if _production_played.has(&"comic_page"):
			break
	await _capture("comic_formal_audio")
	comic.queue_free()
	await get_tree().process_frame
	for id: StringName in [&"ui_click", &"ui_name_confirm", &"ui_identity_switch", &"ui_identity_confirm", &"ui_error", &"comic_write", &"comic_page"]:
		_check(_production_played.has(id), "production UI fact played: %s" % id)


# 接入 C 已合并的 Runtime，用真实假卡命中和真实子体生成验证声音。
func _verify_trait_audio(profile: LevelProfile) -> void:
	var battle: BattleAttemptFlow = _sandbox.get("_battle_attempt_flow") as BattleAttemptFlow
	var area: BarrageArea = battle.get_barrage_area()
	area.stop_normal_generation()
	var catalog := BarrageTraitCatalog.new()
	_check(catalog.load_production_tables(), "load formal trait catalog for audio")
	var runtime := BarrageTraitRuntime.new()
	runtime.bind(area, catalog)
	runtime.begin_attempt(profile)
	_hud.bind_trait_audio(runtime)
	for trait_id: StringName in [BarrageTraitSet.FAKE_CARD, BarrageTraitSet.SPLIT]:
		area.clear_current_barrages()
		var spawn_profile := profile.duplicate() as LevelProfile
		spawn_profile.special_trait_ids = [String(trait_id)]
		var traits: Array[StringName] = [trait_id]
		var view: BarrageView = area.spawn_normal_barrage(spawn_profile, profile.get_normal_speech_pool()[0], traits, true)
		_check(view != null, "formal trait target exists: %s" % trait_id)
		if view == null:
			continue
		if trait_id == BarrageTraitSet.SPLIT:
			var children: Array[BarrageView] = runtime.split_on_normal_hit(view)
			_check(not children.is_empty(), "real split children generated")
		else:
			# 使用原输入系统处理实际假卡，不能直接构造结算字典。
			await get_tree().process_frame
			view.position = area.size * 0.5 - view.size * 0.5
			var aim: AimReticle = battle.get_aim_reticle()
			var point: Vector2 = get_viewport().get_final_transform() * (aim.get_canvas_transform() * view.get_global_rect().get_center())
			for pressed: bool in [true, false]:
				var event := InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT
				event.position = point
				event.pressed = pressed
				Input.parse_input_event(event)
				Input.flush_buffered_events()
				if pressed:
					await get_tree().create_timer(1.0).timeout
			await get_tree().create_timer(0.8).timeout
		await _capture("trait_%s_audio" % trait_id)
	for event_id: StringName in [&"hit_trap", &"trait_split"]:
		_check(_production_played.has(event_id), "real trait fact played: %s" % event_id)
	_hud.bind_trait_audio(null)
	runtime.unbind()
	area.clear_current_barrages()
	area.resume_normal_generation()


# 消费真实候选确认和非空已提交历史；只核对声音，不路由到 Ending 或写磁盘。
func _verify_final_phase_audio(profile: LevelProfile, catalog: LevelCatalog) -> void:
	var deadline: int = Time.get_ticks_msec() + 4000
	while _flow.get_oracle_session() == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var oracle: FinalOracleSession = _flow.get_oracle_session()
	_check(oracle != null and not oracle.get_display_candidates().is_empty(), "real oracle has candidates")
	if oracle == null or oracle.get_display_candidates().is_empty():
		return
	await _capture("oracle_before_confirmation")
	_check(oracle.confirm_display_candidate(oracle.get_display_candidates()[0]), "real displayed oracle confirmed")
	_check(_production_played.has(&"oracle_confirm"), "real confirmation played oracle_confirm")
	var battle: BattleAttemptFlow = _sandbox.get("_battle_attempt_flow") as BattleAttemptFlow
	_flow.stop()
	_sandbox.get("_rest_result_view").hide_result()
	_divine_preview = DivineDescentFlow.new()
	_sandbox.add_child(_divine_preview)
	_hud.bind_audio_flows(_flow, _divine_preview)
	_check(_divine_preview.start(SaveManager.data, catalog, profile,
		preload("res://data/combat_stage/tier_catalog.tres"), battle.get_hit_resolution(),
		battle.get_combat_stage(), null, battle.get_barrage_area(), battle.get_opponent_pk_bar(),
		battle.get_attack_input(), _sandbox.get("battle_config"),
		preload("res://data/divine_descent/divine_descent_decay_config.tres"), {}), "real nonempty divine flow starts")
	deadline = Time.get_ticks_msec() + 25000
	while _divine_preview.get_spread() != null and not _divine_preview.get_spread().is_sentence_locked() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(_production_played.has(&"divine_descent_start") and _production_played.has(&"divine_descent_lock"), "real divine entry and lock played audio")
	await _capture("divine_locked_audio")
	_divine_preview.stop()
	_divine_preview.queue_free()
	_divine_preview = null


# 沿用正式 SD-07 时钟和 48 条闲聊，不缩短正式表间隔；分别观察两侧真实气泡。
func _verify_idle(consumer: RefCounted) -> void:
	var battle: BattleAttemptFlow = _sandbox.get("_battle_attempt_flow") as BattleAttemptFlow
	battle.get_opponent_pk_bar().stop_pullback()
	var candidates: Dictionary = {0: [], 1: []}
	var expected_sides: int = 0
	for entry: BubbleDialogueEntry in consumer.create_dialogue_config("story_level_001").entries:
		if entry.is_random_idle:
			candidates[entry.side].append(entry.text)
		elif entry.side == 1 and entry.event_id == &"combat_connected":
			for bubble: Node in _hud.get_node("%OpponentBubbleStack").get_children():
				if bubble is StreamerBubbleView and bubble.get("_message") == entry.text:
					await _capture("formal_opponent_plot")
	for side: int in candidates:
		if not candidates[side].is_empty():
			expected_sides += 1
	_hud.clear_dialogue_bubbles()
	var seen: Dictionary = {}
	var deadline: int = Time.get_ticks_msec() + 15000
	while seen.size() < expected_sides and Time.get_ticks_msec() < deadline:
		for side: int in [0, 1]:
			var stack: Node = _hud.get_node("%PlayerBubbleStack" if side == 0 else "%OpponentBubbleStack")
			for child: Node in stack.get_children():
				if child is StreamerBubbleView and candidates[side].has(child.get("_message")):
					if not seen.has(side):
						seen[side] = true
						print("INT17D FORMAL IDLE side=%d text=%s" % [side, child.get("_message")])
						await _capture("formal_idle_side%d" % side)
		await get_tree().process_frame
	_check(seen.size() == expected_sides, "formal random idle visible for each configured side at CSV intervals")
	var timed: Node = _sandbox.get("_timed_opponent_dialogue_presenter")
	var queue: Node = _hud.get("_dialogue_queue")
	print("INT17D IDLE STATE tier=%d player_rows=%d opponent_rows=%d timers=%s enabled=%s" % [battle.get_current_tier(), candidates[0].size(), candidates[1].size(), timed.get("_idle_remaining"), queue.get("_side_enabled")])


# 真实 GPU 视口直接写 PNG，媒体永远不进入仓库目录。
func _capture(stem: String) -> void:
	if _output.is_empty():
		return
	await RenderingServer.frame_post_draw
	var screenshot: Image = get_viewport().get_texture().get_image()
	_check(screenshot.get_size() == get_window().size, "GPU frame matches physical window %s" % screenshot.get_size())
	var error := screenshot.save_png(_output.path_join(stem + ".png"))
	_check(error == OK, "GPU capture: " + stem)


# 失败仍保留已完成证据，在最后用非零退出码汇报。
func _check(condition: bool, description: String) -> void:
	if not condition:
		_failed = true
		push_error("INT17D FAIL: " + description)
	else:
		print("INT17D PASS: " + description)
