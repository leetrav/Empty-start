extends Node

const GAME_SCENE: PackedScene = preload("res://scenes/sandbox/sandbox_plan_b.tscn")
const HANDOFF_TIMEOUT_SECONDS: float = 12.0

var _sandbox
var _rest_ready_count: int = 0
var _continue_signal_count: int = 0
var _checks: int = 0
var _failed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	get_tree().create_timer(90.0).timeout.connect(func(): _finish(1))
	_run.call_deferred()


func _run() -> void:
	# 隔离测试存档，从正式 Plan B 第二关绕过开局费米教学。
	SaveManager.new_game()
	SaveManager.data.identity_id = IdentityOptions.CARDS[0].identity_id
	SaveManager.data.streamer_name = "INT-25 TEST_ONLY"
	SaveManager.data.fan_group_name = "闭环 smoke"
	SaveManager.data.tendency_state.initialize_from_identity_option(IdentityOptions.CARDS[0])
	SaveManager.data.next_normal_level_order = 2
	var first_completed: Array[String] = ["level_001"]
	SaveManager.data.completed_normal_level_ids = first_completed
	SceneRouter.game_scene_override = GAME_SCENE
	if not _check(SceneRouter.goto_game() == OK, "正式 Plan B Sandbox 开播请求"):
		_finish(1)
		return
	if not await _wait_until(func(): return _sandbox_ready(), "第二关 Sandbox 初始化"):
		_finish(1)
		return
	_sandbox = get_tree().current_scene
	_observe_sandbox()

	# 首次击破跳过神谕，结算后 Continue 在当前 Sandbox 进入下一关。
	if not await _run_handoff(true):
		_finish(1)
		return
	var success_flow: ContradictionOracleFlow = _sandbox.get_contradiction_oracle_flow()
	var success_session: RestSession = success_flow.get_result()
	_check(success_session != null and success_session.get_result_snapshot().get("result_kind") == "breakthrough_oracle_complete", "成功击破直接创建 RestSession")
	_check(success_flow.get_oracle_session() == null and success_flow.get_selection_timer() == null and success_flow.get_confirmation_state() == null, "成功击破跳过神谕会话、计时和确认")
	_check(_rest_ready_count == 1, "成功结果只交付一次")
	_check(_normal_history_count() == 1 and SaveManager.data.tendency_state.orthodox_total == 2, "成功历史与倾向各提交一次")
	_check(_no_cut_rewards(), "成功击破不新增圣典、败者卡或吞并成果")
	_check(_history_controls_removed(_sandbox.get_rest_result_view()), "结算页无历史入口或奖励空态")
	var success_view: RestResultView = _sandbox.get_rest_result_view()
	success_view.get_node("%ContinueButton").pressed.emit()
	success_view.get_node("%ContinueButton").pressed.emit()
	if not await _wait_until(func(): return get_tree().current_scene == _sandbox and _current_level_order() == 3 and not SceneRouter.is_transitioning(), "继续直播直接进入第三关"):
		_finish(1)
		return
	_check(_continue_signal_count == 1 and SaveManager.data.next_normal_level_order == 3 and SaveManager.data.completed_normal_level_ids.has("level_002"), "继续路线只提交第二关一次")
	_check(_normal_history_count() == 1 and SaveManager.data.tendency_state.orthodox_total == 2, "继续路由没有重复提交成果")

	# 未击破仍进入同一 Rest 菜单；Stop 保存游标并从房间恢复下一关。
	if not await _run_handoff(false):
		_finish(1)
		return
	var unbroken_flow: ContradictionOracleFlow = _sandbox.get_contradiction_oracle_flow()
	var unbroken_session: RestSession = unbroken_flow.get_result()
	_check(unbroken_session != null and unbroken_session.get_result_snapshot().get("result_kind") == "pk_win_unbroken", "未击破结果仍进入 Rest")
	_check(_rest_ready_count == 2, "未击破结果只交付一次")
	print("INT25_UNBROKEN_STATE hits=", _normal_history_count(), " tendency=", SaveManager.data.tendency_state.orthodox_total,
		" attempt=", SaveManager.data.tendency_state.attempt_orthodox_total)
	_check(_normal_history_count() == 2 and SaveManager.data.tendency_state.orthodox_total == 4, "未击破历史与倾向各提交一次")
	_check(_no_cut_rewards(), "未击破不新增裁剪奖励")
	var unbroken_view: RestResultView = _sandbox.get_rest_result_view()
	unbroken_view.get_node("%StopStreamingButton").pressed.emit()
	unbroken_view.get_node("%StopStreamingButton").pressed.emit()
	if not await _wait_until(func(): return _is_opening_room() and not SceneRouter.is_transitioning(), "未击破下播返回休息室"):
		_finish(1)
		return
	_check(SaveManager.data.next_normal_level_order == 4 and SaveManager.data.completed_normal_level_ids.has("level_003"), "下播保存下一关游标")
	var room: Node = get_tree().current_scene
	_check(room.find_child("GalleryButton", true, false) == null and room.find_child("ScriptureButton", true, false) == null, "电脑菜单只保留继续直播")
	room.get_node("LaptopButton").pressed.emit()
	await get_tree().process_frame
	room.get_node("%StartLiveButton").pressed.emit()
	var duplicate_start: Error = room.start_live()
	print("INT25_ROOM_START_DUPLICATE_RESULT=", error_string(duplicate_start), " transition=", SceneRouter.is_transitioning())
	_check(duplicate_start == ERR_ALREADY_IN_USE, "房间重复开播请求被一次性锁拒绝")
	if not await _wait_until(func(): return _sandbox_ready() and _current_level_order() == 4, "从房间恢复第四关"):
		_finish(1)
		return
	_sandbox = get_tree().current_scene
	_observe_sandbox()

	# 末关 Stop 也保留完整周目；从房间再次开播恢复 DivineDescent。
	if not await _run_handoff(true):
		_finish(1)
		return
	var final_view: RestResultView = _sandbox.get_rest_result_view()
	final_view.get_node("%StopStreamingButton").pressed.emit()
	if not await _wait_until(func(): return _is_opening_room() and not SceneRouter.is_transitioning(), "末关下播返回休息室"):
		_finish(1)
		return
	_check(SaveManager.data.normal_campaign_completed and SaveManager.data.completed_normal_level_ids.has("level_004"), "末关下播保存完整普通周目")
	room = get_tree().current_scene
	room.get_node("LaptopButton").pressed.emit()
	await get_tree().process_frame
	room.get_node("%StartLiveButton").pressed.emit()
	duplicate_start = room.start_live()
	print("INT25_FINAL_ROOM_START_DUPLICATE_RESULT=", error_string(duplicate_start), " transition=", SceneRouter.is_transitioning())
	if not await _wait_until(
		func():
			var scene: Node = get_tree().current_scene
			return (scene != null and scene.has_method("get_divine_descent_flow")
				and scene.get_divine_descent_flow() != null
				and scene.get_divine_descent_flow().get_session() != null),
		"末关下播后从房间恢复 DivineDescent"
	):
		_finish(1)
		return
	_check(_normal_history_count() == 3 and _no_cut_rewards(), "末关恢复终局不重复提交或发奖")
	print("INT25_HANDOFF_PASS checks=", _checks, " rest_ready=", _rest_ready_count, " continue=", _continue_signal_count)
	_finish(0)


func _observe_sandbox() -> void:
	var result_flow: ContradictionOracleFlow = _sandbox.get_contradiction_oracle_flow()
	result_flow.repeat_climax_duration_seconds = 0.05
	result_flow.repeat_climax_spawn_seconds = 0.05
	result_flow.repeat_climax_interactive = false
	var fast_config: SandboxBattleConfig = _sandbox.battle_config.duplicate(true) as SandboxBattleConfig
	fast_config.contradiction_repeat_count = 1
	fast_config.contradiction_repeat_lifetime_seconds = 0.1
	_sandbox.battle_config = fast_config
	_sandbox.connect("rest_continue_requested", Callable(self, "_on_rest_continue_requested"))
	result_flow.rest_ready.connect(_on_rest_ready)


func _run_handoff(broken: bool) -> bool:
	var battle: BattleAttemptFlow = _sandbox.get_battle_attempt_flow()
	var level: LevelProfile = battle.get_current_level_profile()
	if not _check(level != null, "当前关卡已就绪"):
		return false
	level.paradox_silence_transition_seconds = 0.05
	var speech: LevelSpeech = level.get_normal_speech_pool()[0]
	battle.get_hit_resolution().record_normal_word_hit(StringName(speech.original_sentence_id), "orthodox")
	SaveManager.data.tendency_state.record_normal_speech_tendency("orthodox", 2)
	var pk_result: Dictionary = _sandbox.debug_set_player_pk_with_status(1.0)
	if not _check(bool(pk_result.get("ok", false)), "受控 PK 满值触发矛盾阶段"):
		return false
	var result_flow: ContradictionOracleFlow = _sandbox.get_contradiction_oracle_flow()
	if not await _wait_until(func(): return result_flow.is_contradiction_active(), "矛盾窗口启动"):
		return false
	var system: ContradictionBreakSystem = result_flow.get_contradiction_system()
	if not _check(system.register_launched_shot(), "受控发出矛盾判定"):
		return false
	var hit_ids: Array[String] = []
	if broken:
		hit_ids.append(level.true_contradictions[0].original_sentence_id)
	else:
		hit_ids.append(level.false_contradictions[0].original_sentence_id)
	system.resolve_shot_hit_ids(hit_ids)
	return await _wait_until(
		func():
			var view: RestResultView = _sandbox.get_rest_result_view()
			return (result_flow.get_result() != null
				and (view.get_node("%Overlay") as Control).visible
				and not (view.get_node("%ContinueButton") as Button).disabled),
		"矛盾反馈后交付并显示 Rest"
	)


func _sandbox_ready() -> bool:
	var scene: Node = get_tree().current_scene
	return (scene != null and scene.has_method("get_battle_attempt_flow")
		and scene.get_battle_attempt_flow() != null
		and scene.get_battle_attempt_flow().is_normal_combat_active())


func _is_sandbox() -> bool:
	var scene: Node = get_tree().current_scene
	return scene != null and scene.has_method("get_battle_attempt_flow")


func _is_opening_room() -> bool:
	return get_tree().current_scene != null and get_tree().current_scene.has_method("start_live")


func _current_level_order() -> int:
	var scene: Node = get_tree().current_scene
	if scene == null or not scene.has_method("get_battle_attempt_flow"):
		return -1
	var profile: LevelProfile = scene.get_battle_attempt_flow().get_current_level_profile()
	return profile.level_order if profile != null else -1


func _history_controls_removed(view: RestResultView) -> bool:
	return (view.find_child("ScriptureHistoryButton", true, false) == null
		and view.find_child("LoserCardHistoryButton", true, false) == null
		and view.find_child("NewRewardsEmpty", true, false) == null)


func _normal_history_count() -> int:
	var hit_total: int = 0
	for entry: Dictionary in SaveManager.data.get_committed_normal_hit_history():
		hit_total += int(entry.get("hit_count", 0))
	return hit_total


func _no_cut_rewards() -> bool:
	return (SaveManager.data.scripture_data.entries.is_empty()
		and SaveManager.data.loser_card_data.acquired_streamer_ids.is_empty()
		and SaveManager.data.assimilation_data.defeated_streamer_ids.is_empty())


func _on_rest_ready(_session: RestSession) -> void:
	_rest_ready_count += 1


func _on_rest_continue_requested(_session: RestSession) -> void:
	_continue_signal_count += 1


func _wait_until(predicate: Callable, label: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(HANDOFF_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await get_tree().process_frame
	var scene: Node = get_tree().current_scene
	var order := _current_level_order()
	var active := false
	if scene != null and scene.has_method("get_battle_attempt_flow"):
		var battle: BattleAttemptFlow = scene.get_battle_attempt_flow()
		active = battle != null and battle.is_normal_combat_active()
	print("INT25_WAIT_STATE label=", label, " path=", scene.scene_file_path if scene != null else "null",
		" sandbox=", _is_sandbox(), " active=", active, " order=", order,
		" transition=", SceneRouter.is_transitioning(), " next=", SaveManager.data.next_normal_level_order)
	return _check(false, "超时等待：" + label)


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		print("INT25 OK: " + message)
		return true
	_failed = true
	push_error("INT25 FAIL: " + message)
	return false


func _finish(exit_code: int) -> void:
	if SceneRouter.game_scene_override == GAME_SCENE:
		SceneRouter.game_scene_override = null
	get_tree().quit(exit_code if not _failed else 1)
