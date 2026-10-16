## PTF-01 实景复播：默认只建立隔离测试身份后停在房间，等待窗口真实输入。
extends Node

var _scenario: String = "manual"
var _capture_index: int = 0
var _elapsed: float = 0.0
var _last_pk: float = -1.0
var _failures: int = 0


## 测试驱动留在树根，不替换生产输入、弹幕位置或攻击参数。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().title = "PTF-01 Lane A manual"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ptf01="):
			_scenario = argument.trim_prefix("--ptf01=")
	_begin.call_deferred()


## 初始场景注册完成后再移交根路由，保持复播观察节点存活。
func _begin() -> void:
	get_tree().current_scene = null
	print("PTF01_USER_DIR=", OS.get_user_data_dir(), " scenario=", _scenario)
	SaveManager.new_game()
	SaveManager.data.identity_id = IdentityOptions.CARDS[0].identity_id
	SaveManager.data.streamer_name = "PTF01 TEST_ONLY"
	SaveManager.data.fan_group_name = "接口验收"
	SaveManager.data.tendency_state.initialize_from_identity_option(IdentityOptions.CARDS[0])
	SceneRouter.goto_opening_room()
	if _scenario != "manual":
		_checks.call_deferred()


## 观察实际状态并记录帧；默认模式不产生攻击或PK调试输入。
func _process(delta: float) -> void:
	_elapsed += delta
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("get_battle_attempt_flow"):
		var flow: BattleAttemptFlow = scene.get_battle_attempt_flow()
		if flow == null or flow.get_hit_resolution() == null:
			return
		var pk := flow.get_hit_resolution().get_player_pk()
		if absf(pk - _last_pk) > 0.0005:
			_last_pk = pk
			print("PTF01_FRAME=", Engine.get_process_frames(), " pk=", pk, " tier=", flow.get_current_tier(), " opponent=", scene.get_opponent_live_snapshot())


## F8仅保存真实画面，F10结束复播；日志记录原始窗口事件供人工核对。
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		print("PTF01_POINTER frame=", Engine.get_process_frames(), " pressed=", event.pressed, " at=", event.position)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			_capture.call_deferred("manual")
		elif event.keycode == KEY_F10:
			get_tree().quit(_failures)


## 辅助边界回归明确使用调试PK和合成触摸，不能替代自然玩家验收。
func _checks() -> void:
	await _frames()
	var room := get_tree().current_scene
	_send_escape()
	await _frames()
	_check(get_tree().paused, "房间ESC开启")
	await _capture("room_pause")
	_send_escape()
	await _frames()
	_check(not get_tree().paused, "房间ESC关闭")
	room.get_node("%StartLiveButton").pressed.emit()
	await _frames()
	var sandbox := get_tree().current_scene
	var flow: BattleAttemptFlow = sandbox.get_battle_attempt_flow()
	var messages: Array[String] = []
	flow.battle_state_changed.connect(func(message: String): messages.append(message))
	if _scenario == "preview":
		sandbox.opponent_reaction_preview_enabled = true
	_check(sandbox.get_opponent_live_snapshot()["comment_count"] == 3, "首批三条对手评论")
	var expected_session := SaveManager.data.get_opponent_live_session("alien")
	_check(expected_session != SaveManager.data.live_session, "两侧数据所有者独立")
	# 正常命中与反弹分别走真实攻击/结算；此处仅清场隔离辅助断言。
	var area := flow.get_barrage_area()
	area.clear_current_barrages()
	var profile := flow.get_current_level_profile()
	var speech: LevelSpeech = profile.get_normal_speech_pool()[0]
	var normal := area.spawn_normal_barrage(profile, speech)
	var before := flow.get_hit_resolution().get_player_pk()
	await _shoot_control(sandbox, normal)
	_check(flow.get_hit_resolution().get_player_pk() > before, "实际普通命中推进PK")
	await _capture("normal_hit")
	area.clear_current_barrages()
	var trap_profile: LevelProfile = profile.duplicate()
	trap_profile.special_trait_ids = [BarrageTraitSet.REFLECT]
	var trap := area.spawn_normal_barrage(trap_profile, speech, [BarrageTraitSet.REFLECT])
	# 同发一个普通目标与一个反弹目标，复现原提示“PK +-0.60%”。
	var mixed := area.spawn_normal_barrage(profile, speech)
	mixed.position = trap.position
	mixed.set_process(false)
	trap.set_process(false)
	before = flow.get_hit_resolution().get_player_pk()
	await _shoot_control(sandbox, trap)
	_check(flow.get_hit_resolution().get_player_pk() < before, "实际反弹扣分")
	_check(not messages.is_empty() and messages.back().contains("PK -0.60%"), "同发净扣分文案无错误正号")
	print("PTF01_MIXED_SHOT=", messages.back())
	await _capture("trap_hit")
	for sample: float in [0.50, 0.57, 0.65, 0.73, 0.81, 0.93, 0.60]:
		sandbox.debug_set_player_pk(sample)
		await get_tree().create_timer(0.45).timeout
		_check(absf(float(sandbox.get_node("%PlayerShare").value) - flow.get_hit_resolution().get_player_pk()) < 0.002, "真实PK与填充一致")
		await _capture("tier_%d" % flow.get_current_tier())
	# 同帧旧Stage回调必须失效，新尝试仍显示50%。
	sandbox.debug_set_player_pk(0.0)
	sandbox.restart_current_attempt()
	await get_tree().create_timer(0.3).timeout
	_check(is_equal_approx(float(sandbox.get_node("%PlayerShare").value), 0.5), "同帧重开丢弃旧PK回调")
	sandbox.debug_set_player_pk(0.0)
	await get_tree().create_timer(0.6).timeout
	_check(not flow.is_normal_combat_active(), "归零真实失败状态")
	await _capture("failure")
	sandbox.restart_current_attempt()
	await get_tree().create_timer(0.3).timeout
	var attack: AttackChargeInput = flow.get_attack_input()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = get_viewport().get_final_transform() * Vector2(960, 400)
	touch.pressed = true
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	await get_tree().create_timer(0.4).timeout
	_send_escape()
	await _frames()
	var captured := attack.get_charge_progress()
	await get_tree().create_timer(0.4).timeout
	_check(is_equal_approx(captured, attack.get_charge_progress()), "暂停冻结蓄力")
	_check(not attack.is_charge_held(), "暂停取消触点捕获_需要C接口")
	_send_escape()
	await _frames()
	touch.pressed = false
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	await _frames()
	_check(attack.get_attack_phase() == AttackChargeInput.AttackPhase.READY, "恢复抬起不意外发射")
	# 真实10秒Paradox超时产生未击破结果，不伪造Rest数据。
	sandbox.debug_set_player_pk(1.0)
	await _wait(func(): return sandbox.get_contradiction_oracle_flow().is_contradiction_active())
	await _capture("paradox")
	await _wait(func(): return sandbox.get_rest_result_view()._overlay.visible)
	await _capture("rest")
	_send_escape()
	await _frames()
	_check(get_tree().paused, "战后ESC开启")
	await _capture("rest_pause")
	_send_escape()
	await _frames()
	_check(not get_tree().paused, "战后ESC恢复")
	print("PTF01_AUX_RESULT failures=", _failures, " opponent=", sandbox.get_opponent_live_snapshot())
	get_tree().quit(0 if _failures == 0 else 1)


## 辅助脚本只注入现有InputMap对应ESC。
func _send_escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## 仅辅助回归使用合成鼠标；目标仍按生产运动与寿命运行。
func _shoot_control(sandbox, target: Control) -> void:
	var point := get_viewport().get_final_transform() * target.get_global_rect().get_center()
	var attack: AttackChargeInput = sandbox.get_battle_attempt_flow().get_attack_input()
	await _wait(func(): return attack.can_start_charging())
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().create_timer(0.9 if pressed else 0.45).timeout


## 核对结果失败时保留运行，汇总明确退出码。
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("PTF01_FAIL " + message)


## 等待真实场景与布局就绪。
func _frames() -> void:
	for index: int in range(4):
		await get_tree().process_frame


## 用游戏帧时间等待回调，MovieWriter慢编码不冒充阶段超时（KT-40）。
func _wait(predicate: Callable) -> void:
	var start := _elapsed
	while not predicate.call():
		if _elapsed - start > 30.0:
			_check(false, "阶段等待超时")
			return
		await get_tree().process_frame


## 证据只留本地D盘，不进入PR。
func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_capture_index += 1
	get_viewport().get_texture().get_image().save_png("res://.godot/ptf01/%s_%02d_%s.png" % [_scenario, _capture_index, label])
