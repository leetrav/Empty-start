extends SceneTree

## 真实Sandbox逐关检查；仅在隔离存档进程内准备关卡进度，不写用户存档。
var _failures: int = 0
var _dialogue_completed: bool = false
var _dialogue_started: bool = false
var _first_low_us: int = 0
var _first_arrow_us: int = 0
var _second_arrow_us: int = 0
var _first_mid_us: int = 0
var _observed_low: StringName
var _observed_mid: StringName


func _on_music_event(event_id: StringName) -> void:
	if event_id == _observed_low and _first_low_us == 0:
		_first_low_us = Time.get_ticks_usec()
	if event_id == _observed_mid and _first_mid_us == 0:
		_first_mid_us = Time.get_ticks_usec()


func _on_arrow_fading(previous_tier: int, current_tier: int) -> void:
	if previous_tier == 0 and current_tier == 1:
		_first_arrow_us = Time.get_ticks_usec()
	if previous_tier == 1 and current_tier == 2:
		_second_arrow_us = Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("_run")

func _check(passed: bool, label: String) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed:
		_failures += 1

func _on_dialogue(event_id: StringName, _sequence: StringName, _side: int) -> void:
	if event_id == &"combat_connected":
		_dialogue_completed = true

func _on_bubble(_side: int, event_id: StringName, _text: String) -> void:
	if event_id == &"combat_connected":
		_dialogue_started = true

func _music_gain(audio: Node) -> float:
	var gain: float = 0.0
	for child: Node in audio.get_children():
		if child is AudioStreamPlayer and child.bus == &"Music" and child.playing:
			gain += child.volume_linear
	return gain

func _run() -> void:
	# 测试失败也要退出，避免断言中止后悬挂游戏进程。
	create_timer(260.0).timeout.connect(func(): quit(2))
	var save: Node = root.get_node("SaveManager")
	var audio: Node = root.get_node("AudioManager")
	audio.music_changed.connect(_on_music_event)
	save.new_game()
	var catalog: LevelCatalog = load("res://data/level_configuration/level_catalog.tres")
	for index: int in range(4):
		var id: String = catalog.profiles[index].streamer_id
		if OS.get_cmdline_user_args().has("--alien-only") and id != "alien":
			continue
		if OS.get_cmdline_user_args().has("--fox-only") and id != "fox":
			continue
		var profile: TierMusicProfile = BossMusicCatalog.find_profile(StringName(id))
		_observed_low = profile.event_ids[1]
		_observed_mid = profile.event_ids[2]
		_first_low_us = 0
		_first_mid_us = 0
		_first_arrow_us = 0
		_second_arrow_us = 0
		save.data.next_normal_level_order = index + 1
		save.data.completed_normal_level_ids.clear()
		for previous: int in range(index):
			save.data.completed_normal_level_ids.append(catalog.profiles[previous].level_id)
		var scene: Node = load("res://scenes/sandbox/sandbox.tscn").instantiate()
		root.add_child(scene)
		scene.get_node("BattleHud").tier_breakthrough_fading.connect(_on_arrow_fading)
		await create_timer(0.2).timeout
		var flow: BattleAttemptFlow = scene.get_battle_attempt_flow()
		_check(flow.get_current_level_profile().streamer_id == id and audio.get_music_event_id() == &"", id + " 身份与T0专属策略")
		if OS.get_cmdline_user_args().has("--terminal-only"):
			scene.debug_set_player_pk(1.0)
			var terminal_wait: float = 7.0
			while not scene.get_contradiction_oracle_flow().is_contradiction_active() and terminal_wait > 0.0:
				await create_timer(0.1).timeout
				terminal_wait -= 0.1
			var system: ContradictionBreakSystem = scene.get_contradiction_oracle_flow().get_contradiction_system()
			_check(system != null and system.register_launched_shot(), id + " 矛盾操作接受发射")
			if system != null:
				var ids: Array[String] = [system.get_true_contradictions()[0].original_sentence_id]
				_check(system.resolve_shot_hit_ids(ids), id + " 真矛盾结果提交")
			await create_timer(0.5).timeout
			_check(audio.get_music_event_id() == &"", id + " 真实击破结果淡出静音")
			scene.queue_free()
			await process_frame
			await create_timer(0.2).timeout
			continue
		_dialogue_completed = false
		_dialogue_started = false
		scene.dialogue_event_sequence_completed.connect(_on_dialogue)
		scene.get_node("BattleHud").dialogue_bubble_presented.connect(_on_bubble)
		# 从PK事实加真实突破阶段进入对白，独立于后面的F3调试路径。
		var attack: Node = scene.get_node("AttackChargeInput")
		var snapshot := AttackTargetSnapshot.new()
		var results: Array[Dictionary] = []
		attack.shot_arrival_resolved.emit(snapshot, results)
		flow.get_hit_resolution().set_player_pk_for_debug(0.58)
		await process_frame
		var expected: StringName = profile.event_ids[0] if profile.entrance_event_id == &"" else profile.entrance_event_id
		_check(audio.get_music_event_id() == expected, id + " 连线采用专属引子/原色出场")
		await create_timer(0.4).timeout
		var before_dialogue: float = audio.get_music_position()
		# 提交整发结果，真实触发清场与HUD突破动画，而非手动伪造完成。
		attack.shot_hit_resolution_submitted.emit(snapshot, {"hit_resolution_result": {"target_results": results}})
		var start_remaining: float = 6.0
		while not _dialogue_started and start_remaining > 0.0:
			await create_timer(0.1).timeout
			start_remaining -= 0.1
		var dialogue_group: int = 0
		_check(_dialogue_started and audio.get_music_event_id() == profile.event_ids[dialogue_group], id + " 真实气泡时已按箭头/对白策略播放")
		if profile.hold_intro_through_first_tier:
			_check(_first_low_us == 0 and _first_arrow_us > 0, id + " 首次箭头只开屏，不切低段")
		if id == "fox":
			_check(audio.get_music_position() >= before_dialogue, "fox 原色出场转对白不重播开头")
		await create_timer(1.0).timeout
		_check(not _dialogue_completed and audio.get_music_event_id() == profile.event_ids[dialogue_group], id + " 对白期间音乐不额外切段")
		var remaining: float = 40.0
		while not _dialogue_completed and remaining > 0.0:
			await create_timer(0.2).timeout
			remaining -= 0.2
		_check(_dialogue_completed, id + " 真实对白完成")
		await create_timer(profile.bar_seconds() + 0.8).timeout
		var after_dialogue: int = 0 if profile.hold_intro_through_first_tier else 1
		_check(audio.get_music_event_id() == profile.event_ids[after_dialogue], id + " 对白结束按配置保持引子/切低段")
		if profile.hold_intro_through_first_tier:
			attack.shot_arrival_resolved.emit(snapshot, results)
			flow.get_hit_resolution().set_player_pk_for_debug(0.66)
			await process_frame
			_check(audio.get_music_event_id() == profile.event_ids[0], id + " 第二次箭头前保持开场")
			attack.shot_hit_resolution_submitted.emit(snapshot, {"hit_resolution_result": {"target_results": results}})
			var transition_wait: float = 6.0
			while audio.get_music_event_id() != profile.event_ids[2] and transition_wait > 0.0:
				await create_timer(0.1).timeout
				transition_wait -= 0.1
			_check(_first_mid_us > 0 and _second_arrow_us > 0 and absi(_first_mid_us - _second_arrow_us) < 10000, id + " 首次切中段与第二次箭头淡出同帧")
		else:
			scene.debug_set_player_pk(0.66)
		await create_timer(profile.bar_seconds() + 0.8).timeout
		_check(audio.get_music_event_id() == profile.event_ids[2], id + " 正常第二次升档到中段")
		var pos: float = audio.get_music_position()
		scene.debug_set_player_pk(0.73)
		await create_timer(0.15).timeout
		_check(audio.get_music_position() > pos, id + " 同组不重播")
		var pause: Node = scene.get_node("PauseMenu")
		pause.pause_game()
		await create_timer(0.15).timeout
		pos = audio.get_music_position()
		await create_timer(0.2).timeout
		_check(absf(audio.get_music_position() - pos) < 0.05, id + " 暂停音乐冻结")
		pause.resume_game()
		scene.debug_set_player_pk(0.92)
		await create_timer(profile.bar_seconds() + 0.8).timeout
		_check(audio.get_music_event_id() == profile.event_ids[3], id + " F3跨档到高段")
		scene.debug_set_player_pk(0.58)
		await create_timer(2.0 + profile.bar_seconds() + 0.8).timeout
		_check(audio.get_music_event_id() == profile.event_ids[1], id + " 持续降档低段")
		scene.restart_current_attempt()
		await create_timer(0.15).timeout
		_check(audio.get_music_event_id() == &"", id + " 重开还原T0无旧曲")
		scene.debug_set_player_pk(0.92)
		await create_timer(0.8).timeout
		_check(audio.get_music_event_id() == profile.event_ids[3], id + " T0直接F3无对白不等待")
		var gain: float = _music_gain(audio)
		scene.debug_set_player_pk(1.0)
		await create_timer(0.3).timeout
		_check(_music_gain(audio) > 0.01 and _music_gain(audio) <= gain * 0.3, id + " 击破转场压低25%")
		remaining = 6.0
		while not scene.get_contradiction_oracle_flow().is_contradiction_active() and remaining > 0.0:
			await create_timer(0.1).timeout
			remaining -= 0.1
		await create_timer(0.4).timeout
		_check(_music_gain(audio) >= gain * 0.95, id + " 矛盾窗口恢复")
		scene.restart_current_attempt()
		scene.debug_set_player_pk(0.66)
		await create_timer(0.6).timeout
		scene.debug_set_player_pk(0.0)
		await create_timer(0.8).timeout
		_check(audio.get_music_event_id() == &"", id + " 失败清理")
		scene.queue_free()
		await process_frame
		await create_timer(0.2).timeout
		_check(audio.get_music_event_id() == &"", id + " 退出清理后可换下一Boss")
	var label: String = "AU03_TERMINAL" if OS.get_cmdline_user_args().has("--terminal-only") else "AU03_FOUR_BOSS"
	print(label + "_PASS" if _failures == 0 else label + "_FAIL %d" % _failures)
	quit(0 if _failures == 0 else 1)
