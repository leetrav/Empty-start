extends Node

signal event_sequence_completed(event_id: StringName, sequence_id: StringName, side: int)

const EVENT_COMBAT_CONNECTED: StringName = &"combat_connected"
const EVENT_TIER_UP: StringName = &"combat_tier_up"
const EVENT_TIER_DOWN: StringName = &"combat_tier_down"
const EVENT_TIER1_TAUNT: StringName = &"combat_tier1_taunt"
const EVENT_COMBAT_WIN: StringName = &"combat_win"
const EVENT_COMBAT_LOSE: StringName = &"combat_lose"
const EVENT_OPPONENT_HIT_ANY: StringName = &"opponent_hit_any"
const EVENT_PARADOX_ENTER: StringName = &"paradox_enter"
const EVENT_PARADOX_BREAKTHROUGH: StringName = &"paradox_breakthrough"
const EVENT_PARADOX_NOT_BROKEN: StringName = &"paradox_not_broken"

var _battle_attempt_flow: BattleAttemptFlow
var _contradiction_oracle_flow: ContradictionOracleFlow
var _bubble_dialogue_config: BubbleDialogueConfig
var _enqueue_dialogue_sequence: Callable
var _plan_b_simulation: Node
var _hud: Node
var _is_configured: bool = false
var _attempt_active: bool = false
var _last_tier: int = CombatStage.INITIAL_TIER
var _has_contradiction_outcome: bool = false
var _paradox_entry_submitted: bool = false
var _opponent_hit_reply_submitted: bool = false
var _seen_tier_up_stages: Dictionary = {}
var _sequence_counter: int = 0
var _pending_script_chains: Array[Dictionary] = []
var _active_script_chain: Dictionary = {}
var _script_by_hud_sequence: Dictionary = {}


# 战斗事实只来自正式 Flow / Simulation；当前关卡对白由正式表装配。
func configure(
		battle_attempt_flow: BattleAttemptFlow,
		contradiction_oracle_flow: ContradictionOracleFlow,
		bubble_dialogue_config: BubbleDialogueConfig,
		enqueue_dialogue_sequence: Callable,
		hud: Node,
		plan_b_simulation: Node = null
) -> bool:
	if _is_configured or not is_inside_tree():
		return false
	if battle_attempt_flow == null or contradiction_oracle_flow == null or bubble_dialogue_config == null:
		return false
	if not enqueue_dialogue_sequence.is_valid() or not is_instance_valid(hud):
		return false
	if not hud.has_signal("dialogue_sequence_completed"):
		return false

	_battle_attempt_flow = battle_attempt_flow
	_contradiction_oracle_flow = contradiction_oracle_flow
	_bubble_dialogue_config = bubble_dialogue_config
	_enqueue_dialogue_sequence = enqueue_dialogue_sequence
	_plan_b_simulation = plan_b_simulation
	_hud = hud
	_battle_attempt_flow.attempt_started.connect(_on_attempt_started)
	_battle_attempt_flow.tier_changed.connect(_on_tier_changed)
	_battle_attempt_flow.tier_transition_completed.connect(_on_tier_transition_completed)
	_battle_attempt_flow.shot_resolved.connect(_on_shot_resolved)
	_battle_attempt_flow.normal_combat_completed.connect(_on_normal_combat_completed)
	_battle_attempt_flow.attempt_failed.connect(_on_attempt_failed)
	_contradiction_oracle_flow.entered.connect(_on_contradiction_entered)
	_contradiction_oracle_flow.outcome_resolved.connect(_on_contradiction_outcome_resolved)
	_hud.connect("dialogue_sequence_completed", Callable(self, "_on_hud_sequence_completed"))
	if (is_instance_valid(_plan_b_simulation)
			and _plan_b_simulation.has_signal("contact_resolved")):
		_plan_b_simulation.connect(
			"contact_resolved", Callable(self, "_on_plan_b_contact_resolved"))
	_is_configured = true
	return true


# 定时脚本也通过同一串行器；TIMED_IDLE 保持低优先级，逐句轮到不同发言侧。
func enqueue_script_sequence(
		entries: Array[BubbleDialogueEntry], event_id: StringName, priority: int
) -> StringName:
	return _enqueue_script_entries(entries, event_id, priority)


# 开始和原地重开都重置本场 Tier、触发去重和未完成的对白链。
func _on_attempt_started(
		_level: LevelProfile,
		_hit_resolution: HitResolution,
		combat_stage: CombatStage,
		_repeat_queue: RepeatDelayQueue
) -> void:
	_attempt_active = true
	_last_tier = combat_stage.get_current_tier() if combat_stage != null else CombatStage.INITIAL_TIER
	_has_contradiction_outcome = false
	_paradox_entry_submitted = false
	_opponent_hit_reply_submitted = false
	_seen_tier_up_stages.clear()
	_pending_script_chains.clear()
	_active_script_chain.clear()
	_script_by_hud_sequence.clear()


# Tier 信号只携带最终档位；与尝试启动时记录的档位比较即可识别真实升降档。
func _on_tier_changed(current_tier: int, _player_pk: float) -> void:
	if not _attempt_active or current_tier == _last_tier:
		return
	var previous_tier: int = _last_tier
	_last_tier = current_tier
	if current_tier > previous_tier:
		# Plan B 的 Host PK 先触发连线/升档 UI 清队列，必须等转场完成再提交对白。
		if (not _battle_attempt_flow.is_tier_breakthrough_pending()
				and not _battle_attempt_flow.uses_external_pk_source()):
			_submit_tier_up_events(previous_tier, current_tier)
	elif current_tier == CombatStage.INITIAL_TIER:
		# T0 表示对手离线；取消涉及对手侧的整段脚本，避免后续玩家句误播。
		_forget_sequences_for_side(BubbleDialogueEntry.SpeakerSide.OPPONENT)
	elif current_tier == 1 and previous_tier > 1:
		if _bubble_dialogue_config.find_by_event(EVENT_TIER1_TAUNT).is_empty():
			_submit_event(EVENT_TIER_DOWN)
		else:
			_submit_event(EVENT_TIER1_TAUNT)
	else:
		_submit_event(EVENT_TIER_DOWN)


# T0→T1 先播连线开场，再依次播该关 T1 剧本；跨档时补齐每个到达档位。
func _on_tier_transition_completed(previous_tier: int, current_tier: int) -> void:
	if not _attempt_active or current_tier != _last_tier or current_tier <= previous_tier:
		return
	_submit_tier_up_events(previous_tier, current_tier)


func _submit_tier_up_events(previous_tier: int, current_tier: int) -> void:
	if previous_tier == CombatStage.INITIAL_TIER and current_tier > CombatStage.INITIAL_TIER:
		_submit_event(EVENT_COMBAT_CONNECTED)

	var configured_tier_entries: Array[BubbleDialogueEntry] = []
	for tier: int in range(maxi(previous_tier + 1, 1), current_tier + 1):
		if _seen_tier_up_stages.has(tier):
			continue
		_seen_tier_up_stages[tier] = true
		var tier_event_id := StringName("combat_tier_up_t%d" % tier)
		configured_tier_entries.append_array(
			_bubble_dialogue_config.find_by_event(tier_event_id))

	if not configured_tier_entries.is_empty():
		_enqueue_script_entries(configured_tier_entries, EVENT_TIER_UP, BubbleDialogueEntry.Priority.PLOT)
		return

	# 兼容既有内存测试配置；正式20表按具体T1-T5事件装配。
	if current_tier > previous_tier + 1 or previous_tier > CombatStage.INITIAL_TIER:
		_submit_event(EVENT_TIER_UP)


# 普通 PK 满是本场胜利事实；后续 Paradox 结果使用独立事件 ID。
func _on_normal_combat_completed(
		_level: LevelProfile, _hit_resolution: HitResolution, _repeat_stats: RepeatGenerationStats
) -> void:
	if not _attempt_active:
		return
	_attempt_active = false
	_submit_event(EVENT_COMBAT_WIN)


# PK 归零只在本次活动尝试触发一次失败对白；重开会由新的 attempt_started 复位。
func _on_attempt_failed(
		_level: LevelProfile,
		_loss_streak_count: int,
		_hit_resolution: HitResolution,
		_repeat_stats: RepeatGenerationStats
) -> void:
	if not _attempt_active:
		return
	_attempt_active = false
	_submit_event(EVENT_COMBAT_LOSE)


# 只把玩家与对手之间真实提交的棋子接触算作通用受击，且每局只播一次避免刷屏。
func _on_plan_b_contact_resolved(
		first_unit_id: int, second_unit_id: int, _outcome: StringName
) -> void:
	if not _attempt_active or _opponent_hit_reply_submitted or not is_instance_valid(_plan_b_simulation):
		return
	var first_snapshot: Variant = _plan_b_simulation.call("get_unit_snapshot", first_unit_id)
	var second_snapshot: Variant = _plan_b_simulation.call("get_unit_snapshot", second_unit_id)
	if not first_snapshot is Dictionary or not second_snapshot is Dictionary:
		return
	var first_team: String = str(first_snapshot.get("team", ""))
	var second_team: String = str(second_snapshot.get("team", ""))
	if ((first_team == "player" and second_team == "opponent")
			or (first_team == "opponent" and second_team == "player")):
		_submit_opponent_hit_reply()


# 旧弹幕战按一次实际命中提交同一通用受击事件。
func _on_shot_resolved(
		_snapshot: AttackTargetSnapshot,
		submission: Dictionary,
		_current_tier: int,
		_repeat_stats: RepeatGenerationStats
) -> void:
	if not _attempt_active or _opponent_hit_reply_submitted:
		return
	var hit_result: Dictionary = submission.get("hit_resolution_result", {})
	if not Array(hit_result.get("target_results", [])).is_empty():
		_submit_opponent_hit_reply()


func _submit_opponent_hit_reply() -> void:
	var entries: Array[BubbleDialogueEntry] = _bubble_dialogue_config.find_by_event(EVENT_OPPONENT_HIT_ANY)
	if entries.is_empty():
		return
	_opponent_hit_reply_submitted = true
	_enqueue_script_entries(entries, EVENT_OPPONENT_HIT_ANY, BubbleDialogueEntry.Priority.PLOT)


# 矛盾流程进入事实触发用户配置的矛盾入场台词；结果事件仍沿用既有独立 ID。
func _on_contradiction_entered(_system: ContradictionBreakSystem) -> void:
	if _paradox_entry_submitted:
		return
	_paradox_entry_submitted = true
	_submit_event(EVENT_PARADOX_ENTER)


func _on_contradiction_outcome_resolved(outcome: int) -> void:
	if _has_contradiction_outcome:
		return
	_has_contradiction_outcome = true
	match outcome:
		ContradictionBreakSystem.Outcome.BREAKTHROUGH:
			_submit_event(EVENT_PARADOX_BREAKTHROUGH)
		ContradictionBreakSystem.Outcome.NOT_BROKEN:
			_submit_event(EVENT_PARADOX_NOT_BROKEN)


# 状态事件统一串行排队；查询事件 ID 与完成事件 ID 可不同，用于保留通用 Tier API。
func _submit_event(event_id: StringName) -> void:
	_enqueue_script_entries(
		_bubble_dialogue_config.find_by_event(event_id),
		event_id,
		BubbleDialogueEntry.Priority.PLOT
	)


func _enqueue_script_entries(
		entries: Array[BubbleDialogueEntry], event_id: StringName, priority: int
) -> StringName:
	var script_entries: Array[BubbleDialogueEntry] = []
	for configured_entry: BubbleDialogueEntry in entries:
		if configured_entry == null or configured_entry.text.strip_edges().is_empty():
			continue
		var script_entry: BubbleDialogueEntry = configured_entry.duplicate(true) as BubbleDialogueEntry
		script_entry.priority = priority
		script_entries.append(script_entry)
	if script_entries.is_empty():
		if event_id != &"":
			event_sequence_completed.emit(event_id, &"", -1)
		return &""

	_sequence_counter += 1
	var sequence_id := StringName("dialogue_script_%d" % _sequence_counter)
	_pending_script_chains.append({
		"sequence_id": sequence_id,
		"event_id": event_id,
		"priority": priority,
		"entries": script_entries,
		"next_index": 0,
		"hud_sequence_id": &"",
	})
	_pump_script_chains()
	return sequence_id


# 剧情高优先级先于闲聊；同优先级严格保留事件到达顺序。
func _pump_script_chains() -> void:
	if not _active_script_chain.is_empty() or _pending_script_chains.is_empty():
		return
	var next_index: int = 0
	for index: int in range(1, _pending_script_chains.size()):
		var candidate: Dictionary = _pending_script_chains[index]
		var current: Dictionary = _pending_script_chains[next_index]
		if int(candidate["priority"]) > int(current["priority"]):
			next_index = index
	_active_script_chain = _pending_script_chains.pop_at(next_index)
	_enqueue_next_script_line()


# 一次交给HUD一条气泡，使跨主播对话按正式 line_order 逐句轮换。
func _enqueue_next_script_line() -> void:
	if _active_script_chain.is_empty():
		return
	var entries: Array[BubbleDialogueEntry] = _active_script_chain["entries"]
	var index: int = int(_active_script_chain["next_index"])
	if index >= entries.size():
		_complete_active_script_chain()
		return
	var entry: BubbleDialogueEntry = entries[index]
	var hud_entries: Array[BubbleDialogueEntry] = [entry]
	var hud_sequence_id := StringName("%s_%d" % [
		_active_script_chain["sequence_id"], index
	])
	var accepted_id: StringName = StringName(
		_enqueue_dialogue_sequence.call(hud_entries, hud_sequence_id)
	)
	if String(accepted_id).is_empty():
		push_error("StreamerBubbleCombatStatePresenter: SD-03 拒绝脚本行 %s。" % entry.dialogue_id)
		_active_script_chain.clear()
		call_deferred("_pump_script_chains")
		return
	_active_script_chain["hud_sequence_id"] = accepted_id
	_script_by_hud_sequence[accepted_id] = {
		"script_sequence_id": _active_script_chain["sequence_id"],
		"side": entry.side,
	}


func _on_hud_sequence_completed(sequence_id: StringName, side: int) -> void:
	if not _script_by_hud_sequence.has(sequence_id):
		return
	var segment: Dictionary = _script_by_hud_sequence[sequence_id]
	_script_by_hud_sequence.erase(sequence_id)
	if _active_script_chain.is_empty():
		return
	if (_active_script_chain["sequence_id"] != segment["script_sequence_id"]
			or int(segment["side"]) != side):
		return
	_active_script_chain["next_index"] = int(_active_script_chain["next_index"]) + 1
	if (int(_active_script_chain["priority"]) < BubbleDialogueEntry.Priority.PLOT
			and _has_pending_plot_script()):
		_pending_script_chains.append(_active_script_chain)
		_active_script_chain = {}
		_pump_script_chains()
		return
	_enqueue_next_script_line()


func _complete_active_script_chain() -> void:
	var completed_chain: Dictionary = _active_script_chain
	_active_script_chain = {}
	var event_id: StringName = completed_chain["event_id"]
	if event_id != &"":
		var entries: Array[BubbleDialogueEntry] = completed_chain["entries"]
		var final_side: int = entries.back().side if not entries.is_empty() else -1
		event_sequence_completed.emit(event_id, completed_chain["sequence_id"], final_side)
	call_deferred("_pump_script_chains")


func _has_pending_plot_script() -> bool:
	for chain: Dictionary in _pending_script_chains:
		if int(chain["priority"]) >= BubbleDialogueEntry.Priority.PLOT:
			return true
	return false


# 对手离线或尝试重开时，删除整条涉及该侧的跨侧脚本，不发虚假的完成信号。
func _forget_sequences_for_side(side: int) -> void:
	if not _active_script_chain.is_empty() and _script_chain_has_side(_active_script_chain, side):
		_script_by_hud_sequence.erase(_active_script_chain.get("hud_sequence_id", &""))
		_active_script_chain.clear()
	var retained: Array[Dictionary] = []
	for chain: Dictionary in _pending_script_chains:
		if not _script_chain_has_side(chain, side):
			retained.append(chain)
	_pending_script_chains = retained
	call_deferred("_pump_script_chains")


func _script_chain_has_side(chain: Dictionary, side: int) -> bool:
	var entries: Array[BubbleDialogueEntry] = chain.get("entries", [])
	for entry: BubbleDialogueEntry in entries:
		if entry.side == side:
			return true
	return false


# 沙盒销毁时解除公开 Flow、Simulation 和 HUD 信号连接。
func _exit_tree() -> void:
	if is_instance_valid(_battle_attempt_flow):
		if _battle_attempt_flow.attempt_started.is_connected(_on_attempt_started):
			_battle_attempt_flow.attempt_started.disconnect(_on_attempt_started)
		if _battle_attempt_flow.tier_changed.is_connected(_on_tier_changed):
			_battle_attempt_flow.tier_changed.disconnect(_on_tier_changed)
		if _battle_attempt_flow.tier_transition_completed.is_connected(_on_tier_transition_completed):
			_battle_attempt_flow.tier_transition_completed.disconnect(_on_tier_transition_completed)
		if _battle_attempt_flow.shot_resolved.is_connected(_on_shot_resolved):
			_battle_attempt_flow.shot_resolved.disconnect(_on_shot_resolved)
		if _battle_attempt_flow.normal_combat_completed.is_connected(_on_normal_combat_completed):
			_battle_attempt_flow.normal_combat_completed.disconnect(_on_normal_combat_completed)
		if _battle_attempt_flow.attempt_failed.is_connected(_on_attempt_failed):
			_battle_attempt_flow.attempt_failed.disconnect(_on_attempt_failed)
	if is_instance_valid(_contradiction_oracle_flow):
		if _contradiction_oracle_flow.entered.is_connected(_on_contradiction_entered):
			_contradiction_oracle_flow.entered.disconnect(_on_contradiction_entered)
		if _contradiction_oracle_flow.outcome_resolved.is_connected(_on_contradiction_outcome_resolved):
			_contradiction_oracle_flow.outcome_resolved.disconnect(_on_contradiction_outcome_resolved)
	if (is_instance_valid(_plan_b_simulation)
			and _plan_b_simulation.has_signal("contact_resolved")
			and _plan_b_simulation.is_connected(
				"contact_resolved", Callable(self, "_on_plan_b_contact_resolved"))):
		_plan_b_simulation.disconnect(
			"contact_resolved", Callable(self, "_on_plan_b_contact_resolved"))
	if is_instance_valid(_hud) and _hud.is_connected(
		"dialogue_sequence_completed", Callable(self, "_on_hud_sequence_completed")
	):
		_hud.disconnect("dialogue_sequence_completed", Callable(self, "_on_hud_sequence_completed"))
