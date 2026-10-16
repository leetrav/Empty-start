class_name DivineDescentFlow
extends Node

signal entered(session: DivineDescentSession)
signal completed(result: EndingSession)
signal phase_changed(phase: StringName, prompt: String, progress: float)
signal interaction_received(phase: StringName)

# A/B 演示参数；自动路径仍按 15 表完成，玩家输入可显式注入衰减推进量。
@export var interaction_decay_step_seconds: float = 0.0
@export var interaction_repeat_enabled: bool = false
@export var interaction_scale: float = 1.12
@export var interaction_return_seconds: float = 0.25
@export var repeat_presentation_config: Resource = preload("res://data/repeat/repeat_presentation_config.tres")
var _feedback: Control
var _feedback_layer: CanvasLayer
var _input_cooldown: float = 0.0
var _phase: StringName = &"spreading"

var _session: DivineDescentSession
var _mode: DivineDescentCombatMode
var _spread: DivineDescentSpread
var _result: EndingSession
var _catalog: LevelCatalog
var _area: BarrageArea
var _attack_input: AttackChargeInput
var _presentation: Dictionary
var _stopped: bool = false
var _auto_repeat_min_seconds: float = 0.0
var _auto_repeat_max_seconds: float = 0.0
var _converge_ratio: float = 0.0
var _final_emphasis_duration_seconds: float = 0.0


# INT-16 根场景在 start 前传入 15 表扩散和收束参数。
func configure_formal_parameters(
		auto_repeat_min_seconds: float, auto_repeat_max_seconds: float,
		converge_ratio: float, final_emphasis_duration_seconds: float
) -> bool:
	if _session != null or auto_repeat_min_seconds <= 0.0 or auto_repeat_max_seconds < auto_repeat_min_seconds:
		return false
	if not is_finite(auto_repeat_min_seconds) or not is_finite(auto_repeat_max_seconds):
		return false
	if not is_finite(converge_ratio) or not is_finite(final_emphasis_duration_seconds):
		return false
	if converge_ratio <= 0.0 or converge_ratio > 1.0 or final_emphasis_duration_seconds <= 0.0:
		return false
	_auto_repeat_min_seconds = auto_repeat_min_seconds
	_auto_repeat_max_seconds = auto_repeat_max_seconds
	_converge_ratio = converge_ratio
	_final_emphasis_duration_seconds = final_emphasis_duration_seconds
	return true


# 一次终局使用同一冻结会话和战斗组件；entered 让根场景先收起普通阶段。
func start(
		run_data: SaveData, catalog: LevelCatalog, current_level: LevelProfile,
		tier_catalog: CombatStageTierCatalog, hit_resolution: HitResolution,
		combat_stage: CombatStage, contradiction_break: ContradictionBreakSystem,
		area: BarrageArea, opponent_pk_bar: OpponentPKBar, attack_input: AttackChargeInput,
		battle_config: SandboxBattleConfig, decay_config: DivineDescentDecayConfig,
		presentation: Dictionary
) -> bool:
	if not is_inside_tree() or _session != null or _stopped:
		return false
	if catalog == null or current_level == null or battle_config == null or not is_instance_valid(area) or not is_instance_valid(attack_input):
		return false
	if decay_config == null or not is_finite(decay_config.new_word_decay_duration_seconds) or decay_config.new_word_decay_duration_seconds <= 0.0:
		return false
	# 正式 Resource 兜住旧 Sandbox 的零演出参数；显式配置仍可覆盖本次时序。
	if _auto_repeat_min_seconds <= 0.0:
		var legacy_interval := float(presentation.get("repeat_interval_seconds", 0.0))
		var configured_min := legacy_interval if legacy_interval > 0.0 else decay_config.auto_repeat_interval_min_seconds
		var configured_max := legacy_interval if legacy_interval > 0.0 else decay_config.auto_repeat_interval_max_seconds
		if not configure_formal_parameters(configured_min, configured_max, decay_config.converge_ratio, decay_config.final_emphasis_duration_seconds):
			return false
	var session := DivineDescentSession.new()
	if not session.enter(run_data):
		return false
	var mode := DivineDescentCombatMode.new()
	if not mode.enter_terminal_mode(tier_catalog, hit_resolution, combat_stage,
			contradiction_break, area, opponent_pk_bar):
		return false
	_session = session
	_mode = mode
	_catalog = catalog
	_area = area
	_attack_input = attack_input
	_presentation = presentation.duplicate(true)
	entered.emit(session)
	if _stopped or not is_inside_tree():
		return true
	# 空原始历史直接接收；延迟到根场景完成本次 Continue 回调后再转场。
	if session.should_enter_empty_ending():
		_complete.call_deferred(session)
		return true
	_spread = DivineDescentSpread.new()
	add_child(_spread)
	_spread.completed.connect(_complete)
	_spread.convergence_started.connect(_on_convergence)
	_spread.presentation_config = repeat_presentation_config
	_spread.bind_new_word_decay(mode)
	var repeat_min := _auto_repeat_min_seconds if _auto_repeat_min_seconds > 0.0 else float(_presentation["repeat_interval_seconds"])
	var repeat_max := _auto_repeat_max_seconds if _auto_repeat_max_seconds > 0.0 else repeat_min
	if not _spread.start(session, area, catalog, repeat_min,
			repeat_presentation_config.terminal_lifetime_seconds, battle_config.repeat_display_template,
			null, _presentation.get("trait_colors", {}), repeat_min, repeat_max,
			_converge_ratio if _converge_ratio > 0.0 else 0.9):
		push_error("DivineDescentFlow: 神降临扩散无法读取冻结历史候选。")
		stop()
		return false
	if not area.start_normal_generation(current_level) or not mode.start_new_word_decay(decay_config):
		_spread.stop()
		push_error("DivineDescentFlow: 神降临新话衰减启动失败。")
		stop()
		return false
	_feedback_layer = CanvasLayer.new()
	_feedback_layer.layer = 21
	add_child(_feedback_layer)
	_feedback = preload("res://core/divine_descent/divine_descent_interaction_view.gd").new()
	_feedback_layer.add_child(_feedback)
	_refresh_interaction_phase()
	return true


# 根场景按游戏帧推进，暂停或完成后停止衰减。
func advance(delta: float) -> void:
	if _stopped or _result != null or _spread == null or not is_inside_tree() or get_tree().paused:
		return
	_input_cooldown = maxf(_input_cooldown - delta, 0.0)
	_mode.advance_new_word_decay(delta)
	_refresh_interaction_phase()


# 根输入入口覆盖触摸、左键与空格；零旧强化参数改用可编辑反馈值。
func handle_input(event: InputEvent) -> bool:
	if _stopped or _result != null or _spread == null or not is_inside_tree() or get_tree().paused:
		return false
	var requested: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	requested = requested or (event is InputEventScreenTouch and event.pressed)
	requested = requested or (event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo)
	if not requested:
		return false
	# 触摸仿真鼠标和持续连点共用冷却，避免同一次操作增加两次权重。
	if _input_cooldown > 0.0:
		return true
	_input_cooldown = 0.12
	if is_instance_valid(_feedback):
		var point := _feedback.size * 0.5
		if event is InputEventMouseButton or event is InputEventScreenTouch:
			point = event.position
		_feedback.respond(point)
	if not _spread.is_converging():
		if interaction_repeat_enabled:
			_spread.generate_next_repeat()
		if interaction_decay_step_seconds > 0.0 and not _mode.is_new_word_decay_complete():
			_mode.advance_new_word_decay(interaction_decay_step_seconds)
	var scale_value := float(_presentation.get("input_scale", 0.0))
	var return_value := float(_presentation.get("input_return_seconds", 0.0))
	_spread.respond_to_player(scale_value if scale_value > 1.0 else interaction_scale,
		return_value if return_value > 0.0 else interaction_return_seconds)
	_refresh_interaction_phase()
	interaction_received.emit(_phase)
	return true


# 可读阶段以真实衰减、锁句和收束状态为依据，状态通知供根场景复用。
func _refresh_interaction_phase() -> void:
	var progress := _mode.get_new_word_decay_progress()
	var prompt := "神降临 · 点击 / 触摸 / 空格，让话语回应你"
	_phase = &"spreading"
	if _spread.is_sentence_locked():
		_phase = &"locked"
		progress = _spread.get_locked_visible_ratio()
		prompt = "话语已锁定 · 点击强化 · 正在汇聚"
	if _spread.is_converging():
		_phase = &"emphasis"
		progress = 1.0
		prompt = "神谕显现 · 点击回应 · 即将进入结局"
	if is_instance_valid(_feedback):
		_feedback.show_phase(prompt, progress)
	phase_changed.emit(_phase, prompt, progress)


# 真实可见占比收束后沿用 DD-17 时长，完成仍由 Tween 通知。
func _on_convergence(_candidate: Dictionary) -> void:
	if _stopped:
		return
	if _final_emphasis_duration_seconds > 0.0:
		if not _spread.begin_full_screen_emphasis_total(_final_emphasis_duration_seconds):
			push_error("DivineDescentFlow: 神降临全屏强调启动失败。")
	elif not _spread.begin_full_screen_emphasis(float(_presentation["fade_seconds"]), float(_presentation["hold_seconds"])):
		push_error("DivineDescentFlow: 神降临全屏强调启动失败。")


# 同一会话仅接收一次 Ending；存盘和顶层切换交给根场景。
func _complete(session: DivineDescentSession) -> void:
	if _stopped or not is_inside_tree() or session != _session or _result != null:
		return
	if not session.should_enter_empty_ending() and (_spread == null or not _spread.is_completed()):
		return
	var result := EndingSession.new()
	if not result.receive_final_state(session, _catalog):
		push_error("DivineDescentFlow: Ending 拒绝终局固定结果。")
		return
	_result = result
	if is_instance_valid(_feedback_layer):
		_feedback_layer.queue_free()
	phase_changed.emit(&"completed", "神降临完成 · 进入结局", 1.0)
	_attack_input.set_combat_active(false)
	_area.stop_normal_generation()
	if _spread != null:
		_spread.stop()
	completed.emit(result)


# 显式中止取消 Timer、Tween 和输入；中断及离树均不产生完成事实。
func stop() -> void:
	_stopped = true
	if is_instance_valid(_feedback_layer):
		_feedback_layer.queue_free()
	if is_instance_valid(_attack_input):
		_attack_input.set_combat_active(false)
	if is_instance_valid(_area):
		_area.stop_normal_generation()
	if is_instance_valid(_spread):
		_spread.stop()
		# 离树立即触发 DD-17 的 Tween 清理，避免中断后收到延迟 finished。
		remove_child(_spread)
		_spread.queue_free()
		_spread = null


# 销毁作为最终清理；调用方也可在换场请求前显式停止。
func _exit_tree() -> void:
	stop()


# 读取原会话引用，冻结快照仍由 Session 的公开接口提供副本。
func get_session() -> DivineDescentSession:
	return _session


# 读取当前模式，规则继续归原组件。
func get_combat_mode() -> DivineDescentCombatMode:
	return _mode


# 读取当前扩散状态，工作池继续归原组件。
func get_spread() -> DivineDescentSpread:
	return _spread


# null 表示尚未完成接收；有结果时返回已经接收的同一 Ending。
func get_result() -> EndingSession:
	return _result
