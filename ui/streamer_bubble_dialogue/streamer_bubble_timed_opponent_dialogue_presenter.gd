extends Node

const TIMED_DIALOGUE_EVENT_ID: StringName = &"timed"

var _battle_attempt_flow: BattleAttemptFlow
var _bubble_dialogue_config: BubbleDialogueConfig
var _enqueue_dialogue_bubble: Callable
var _enqueue_script_sequence: Callable
var _script_presenter: Node
var _is_configured: bool = false
var _attempt_active: bool = false
var _elapsed_seconds: float = 0.0
var _next_entry_index: int = 0
var _scheduled_entries: Array[Dictionary] = []
var _due_entries: Array[BubbleDialogueEntry] = []
var _idle_remaining: Dictionary = {}
var _idle_groups_by_lead_side: Dictionary = {}
var _idle_sequence_by_id: Dictionary = {}
var _last_idle_group_by_side: Dictionary = {}
var _idle_ranges: Dictionary = {
	BubbleDialogueEntry.SpeakerSide.PLAYER: Vector2(6.0, 10.0),
	BubbleDialogueEntry.SpeakerSide.OPPONENT: Vector2(7.0, 12.0),
}


# 时钟随普通尝试开始与重开重置；脚本串行器负责多发言侧对白的逐句完成。
func configure(
		battle_attempt_flow: BattleAttemptFlow,
		bubble_dialogue_config: BubbleDialogueConfig,
		enqueue_dialogue_bubble: Callable,
		script_presenter: Node = null
) -> bool:
	if _is_configured or not is_inside_tree():
		return false
	if battle_attempt_flow == null or bubble_dialogue_config == null:
		return false
	if not enqueue_dialogue_bubble.is_valid():
		return false

	_battle_attempt_flow = battle_attempt_flow
	_bubble_dialogue_config = bubble_dialogue_config
	_enqueue_dialogue_bubble = enqueue_dialogue_bubble
	_script_presenter = script_presenter
	if is_instance_valid(_script_presenter):
		_enqueue_script_sequence = Callable(_script_presenter, "enqueue_script_sequence")
		if _script_presenter.has_signal("event_sequence_completed"):
			_script_presenter.connect(
				"event_sequence_completed", Callable(self, "_on_script_sequence_completed"))
	_load_idle_ranges()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_battle_attempt_flow.attempt_started.connect(_on_attempt_started)
	_battle_attempt_flow.normal_combat_completed.connect(_on_normal_combat_completed)
	_battle_attempt_flow.attempt_failed.connect(_on_attempt_failed)
	_is_configured = true
	# 支持组合方在已开始的真实尝试中绑定配置，不要求再次伪造 attempt_started 信号。
	if _battle_attempt_flow.is_normal_combat_active():
		_on_attempt_started(
			_battle_attempt_flow.get_current_level_profile(),
			_battle_attempt_flow.get_hit_resolution(),
			_battle_attempt_flow.get_combat_stage(),
			_battle_attempt_flow.get_repeat_queue())
	return true


# 本场重开重新读当前表配置并清空旧计时与待提交条目。
func _on_attempt_started(
		_level: LevelProfile,
		_hit_resolution: HitResolution,
		_combat_stage: CombatStage,
		_repeat_queue: RepeatDelayQueue
) -> void:
	_attempt_active = true
	_elapsed_seconds = 0.0
	_next_entry_index = 0
	_due_entries.clear()
	_scheduled_entries.clear()
	_idle_remaining.clear()
	_idle_groups_by_lead_side.clear()
	_idle_sequence_by_id.clear()
	_last_idle_group_by_side.clear()
	for side: int in [BubbleDialogueEntry.SpeakerSide.PLAYER, BubbleDialogueEntry.SpeakerSide.OPPONENT]:
		_idle_remaining[side] = _roll_idle_interval(side)
	_build_idle_groups()

	var timed_entries: Array[BubbleDialogueEntry] = []
	for entry: BubbleDialogueEntry in _bubble_dialogue_config.entries:
		if entry != null and entry.event_id == TIMED_DIALOGUE_EVENT_ID:
			timed_entries.append(entry)
	for config_order: int in range(timed_entries.size()):
		var source_entry: BubbleDialogueEntry = timed_entries[config_order]
		if source_entry == null or source_entry.text.strip_edges().is_empty():
			continue
		if source_entry.is_random_idle:
			continue
		if source_entry.trigger_time_seconds < 0.0:
			push_warning("SD-07: 定时对白触发时间不能小于 0 秒。")
			continue
		var timed_entry: BubbleDialogueEntry = source_entry.duplicate(true) as BubbleDialogueEntry
		timed_entry.priority = source_entry.priority
		_scheduled_entries.append({
			"trigger_time_seconds": source_entry.trigger_time_seconds,
			"config_order": config_order,
			"entry": timed_entry,
		})
	_scheduled_entries.sort_custom(_scheduled_entry_precedes)


# 将一个 random_idle trigger_key 装成一组，保留跨侧 line_order 与组级随机权重。
func _build_idle_groups() -> void:
	var grouped_entries: Dictionary = {}
	for entry: BubbleDialogueEntry in _bubble_dialogue_config.entries:
		if (entry == null or entry.event_id != TIMED_DIALOGUE_EVENT_ID
				or not entry.is_random_idle or entry.text.strip_edges().is_empty()):
			continue
		var group_key: String = entry.trigger_key
		if group_key.is_empty():
			group_key = entry.dialogue_id
		if group_key.is_empty():
			continue
		if not grouped_entries.has(group_key):
			grouped_entries[group_key] = []
		grouped_entries[group_key].append(entry)

	for group_key: String in grouped_entries:
		var entries: Array[BubbleDialogueEntry] = []
		for entry_value: Variant in grouped_entries[group_key]:
			if entry_value is BubbleDialogueEntry:
				entries.append(entry_value)
		entries.sort_custom(_entry_precedes)
		if entries.is_empty():
			continue
		var lead_side: int = entries[0].side
		var requires_opponent: bool = false
		for entry: BubbleDialogueEntry in entries:
			if entry.side == BubbleDialogueEntry.SpeakerSide.OPPONENT:
				requires_opponent = true
		var lead_weight: float = maxf(0.0, entries[0].random_weight)
		var group := {
			"key": group_key,
			"entries": entries,
			"lead_side": lead_side,
			"requires_opponent": requires_opponent,
			"weight": lead_weight,
		}
		if not _idle_groups_by_lead_side.has(lead_side):
			_idle_groups_by_lead_side[lead_side] = []
		_idle_groups_by_lead_side[lead_side].append(group)


func _entry_precedes(left: BubbleDialogueEntry, right: BubbleDialogueEntry) -> bool:
	if left.line_order != right.line_order:
		return left.line_order < right.line_order
	return left.source_order < right.source_order


# 定时行按触发秒数排序；相同时间沿用 20 表行序。
func _scheduled_entry_precedes(left: Dictionary, right: Dictionary) -> bool:
	var left_time: float = float(left["trigger_time_seconds"])
	var right_time: float = float(right["trigger_time_seconds"])
	if left_time != right_time:
		return left_time < right_time
	return int(left["config_order"]) < int(right["config_order"])


# 普通尝试中累计秒数；T0 离线期间暂存到点条目，连线后再交给 HUD。
func _process(delta: float) -> void:
	if not _attempt_active:
		return
	_elapsed_seconds += delta
	while _next_entry_index < _scheduled_entries.size():
		var scheduled_entry: Dictionary = _scheduled_entries[_next_entry_index]
		if float(scheduled_entry["trigger_time_seconds"]) > _elapsed_seconds:
			break
		_due_entries.append(scheduled_entry["entry"] as BubbleDialogueEntry)
		_next_entry_index += 1
	_flush_due_entries()
	_drop_disconnected_idle_sequences()
	_advance_random_idle(delta)


func _flush_due_entries() -> void:
	for entry: BubbleDialogueEntry in _due_entries.duplicate():
		if (entry.side == BubbleDialogueEntry.SpeakerSide.OPPONENT
				and _battle_attempt_flow.get_current_tier() <= CombatStage.INITIAL_TIER):
			continue
		if bool(_enqueue_dialogue_bubble.call(entry)):
			_due_entries.erase(entry)


# 闲聊不抢同侧正在播出的剧情；T0 时暂停需要对手参与的整组对话。
func _advance_random_idle(delta: float) -> void:
	for side: int in _idle_remaining.keys():
		if _has_idle_sequence_for_side(side):
			continue
		_idle_remaining[side] = float(_idle_remaining[side]) - delta
		if float(_idle_remaining[side]) > 0.0:
			continue
		if (side == BubbleDialogueEntry.SpeakerSide.OPPONENT
				and _battle_attempt_flow.get_current_tier() <= CombatStage.INITIAL_TIER):
			continue
		var group: Dictionary = _pick_idle_group(side)
		if group.is_empty():
			_idle_remaining[side] = _roll_idle_interval(side)
			continue
		var entries: Array[BubbleDialogueEntry] = group["entries"]
		if _enqueue_script_sequence.is_valid():
			var sequence_id: StringName = StringName(_enqueue_script_sequence.call(
				entries, TIMED_DIALOGUE_EVENT_ID, BubbleDialogueEntry.Priority.TIMED_IDLE))
			if String(sequence_id).is_empty():
				_idle_remaining[side] = _roll_idle_interval(side)
				continue
			_idle_sequence_by_id[sequence_id] = {
				"side": side,
				"requires_opponent": bool(group["requires_opponent"]),
				"group_key": str(group["key"]),
			}
			_last_idle_group_by_side[side] = str(group["key"])
		else:
			# 旧单侧测试夹具没有脚本串行器时保留单句兼容入口。
			var first_entry: BubbleDialogueEntry = entries[0].duplicate(true) as BubbleDialogueEntry
			first_entry.priority = BubbleDialogueEntry.Priority.TIMED_IDLE
			if bool(_enqueue_dialogue_bubble.call(first_entry)):
				_idle_remaining[side] = _roll_idle_interval(side)


func _pick_idle_group(side: int) -> Dictionary:
	var candidates: Array = _idle_groups_by_lead_side.get(side, [])
	if candidates.is_empty():
		return {}
	var previous_key: String = str(_last_idle_group_by_side.get(side, ""))
	var filtered: Array = []
	if candidates.size() > 1:
		for candidate: Dictionary in candidates:
			if str(candidate.get("key", "")) != previous_key:
				filtered.append(candidate)
	if not filtered.is_empty():
		candidates = filtered
	var total: float = 0.0
	for candidate: Dictionary in candidates:
		if bool(candidate.get("requires_opponent", false)) and _battle_attempt_flow.get_current_tier() <= CombatStage.INITIAL_TIER:
			continue
		total += maxf(0.0, float(candidate.get("weight", 0.0)))
	if total <= 0.0:
		return {}
	var target: float = randf() * total
	for candidate: Dictionary in candidates:
		if bool(candidate.get("requires_opponent", false)) and _battle_attempt_flow.get_current_tier() <= CombatStage.INITIAL_TIER:
			continue
		target -= maxf(0.0, float(candidate.get("weight", 0.0)))
		if target <= 0.0:
			return candidate
	return {}


func _has_idle_sequence_for_side(side: int) -> bool:
	for sequence: Dictionary in _idle_sequence_by_id.values():
		if int(sequence.get("side", -1)) == side:
			return true
	return false


func _drop_disconnected_idle_sequences() -> void:
	if _battle_attempt_flow.get_current_tier() > CombatStage.INITIAL_TIER:
		return
	for sequence_id: StringName in _idle_sequence_by_id.keys().duplicate():
		var record: Dictionary = _idle_sequence_by_id[sequence_id]
		if bool(record.get("requires_opponent", false)):
			_idle_sequence_by_id.erase(sequence_id)
			var side: int = int(record.get("side", -1))
			_idle_remaining[side] = _roll_idle_interval(side)


func _on_script_sequence_completed(
		event_id: StringName, sequence_id: StringName, _side: int
) -> void:
	if event_id != TIMED_DIALOGUE_EVENT_ID or not _idle_sequence_by_id.has(sequence_id):
		return
	var record: Dictionary = _idle_sequence_by_id[sequence_id]
	_idle_sequence_by_id.erase(sequence_id)
	var side: int = int(record.get("side", -1))
	if side >= 0:
		_idle_remaining[side] = _roll_idle_interval(side)


func _roll_idle_interval(side: int) -> float:
	var range: Vector2 = _idle_ranges.get(side, Vector2(6.0, 10.0))
	return randf_range(range.x, maxf(range.x, range.y))


func _load_idle_ranges() -> void:
	# 06 基础参数已定义双方节奏，表缺失时沿用 SD-07 的正式默认范围。
	var file := FileAccess.open("res://data/source_tables/06_基础参数.csv", FileAccess.READ)
	if file == null:
		return
	var headers := file.get_csv_line()
	var values: Dictionary = {}
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size() < 2:
			continue
		var row: Dictionary = {}
		for i: int in mini(headers.size(), cells.size()):
			row[str(headers[i])] = cells[i]
		values[str(row.get("param_id", ""))] = str(row.get("value", ""))
	_idle_ranges[BubbleDialogueEntry.SpeakerSide.PLAYER] = Vector2(
		float(values.get("streamer_idle_player_interval_min_s", "6")),
		float(values.get("streamer_idle_player_interval_max_s", "10")))
	_idle_ranges[BubbleDialogueEntry.SpeakerSide.OPPONENT] = Vector2(
		float(values.get("streamer_idle_opponent_interval_min_s", "7")),
		float(values.get("streamer_idle_opponent_interval_max_s", "12")))


func _on_normal_combat_completed(
		_level: LevelProfile, _hit_resolution: HitResolution, _repeat_stats: RepeatGenerationStats
) -> void:
	_stop_attempt_clock()


func _on_attempt_failed(
		_level: LevelProfile,
		_loss_streak_count: int,
		_hit_resolution: HitResolution,
		_repeat_stats: RepeatGenerationStats
) -> void:
	_stop_attempt_clock()


func _stop_attempt_clock() -> void:
	_attempt_active = false
	_due_entries.clear()
	_idle_remaining.clear()
	_idle_sequence_by_id.clear()


# Sandbox 销毁时解除信号连接，避免旧尝试在后续场景中继续触发。
func _exit_tree() -> void:
	if is_instance_valid(_battle_attempt_flow):
		if _battle_attempt_flow.attempt_started.is_connected(_on_attempt_started):
			_battle_attempt_flow.attempt_started.disconnect(_on_attempt_started)
		if _battle_attempt_flow.normal_combat_completed.is_connected(_on_normal_combat_completed):
			_battle_attempt_flow.normal_combat_completed.disconnect(_on_normal_combat_completed)
		if _battle_attempt_flow.attempt_failed.is_connected(_on_attempt_failed):
			_battle_attempt_flow.attempt_failed.disconnect(_on_attempt_failed)
	if (is_instance_valid(_script_presenter)
			and _script_presenter.has_signal("event_sequence_completed")
			and _script_presenter.is_connected(
				"event_sequence_completed", Callable(self, "_on_script_sequence_completed"))):
		_script_presenter.disconnect(
			"event_sequence_completed", Callable(self, "_on_script_sequence_completed"))
