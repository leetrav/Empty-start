extends Node

const TIMED_DIALOGUE_EVENT_ID: StringName = &"timed"

var _battle_attempt_flow: BattleAttemptFlow
var _bubble_dialogue_config: BubbleDialogueConfig
var _enqueue_dialogue_bubble: Callable
var _is_configured: bool = false
var _attempt_active: bool = false
var _elapsed_seconds: float = 0.0
var _idle_remaining: Dictionary = {}
var _idle_ranges: Dictionary = {
	BubbleDialogueEntry.SpeakerSide.PLAYER: Vector2(6.0, 10.0),
	BubbleDialogueEntry.SpeakerSide.OPPONENT: Vector2(7.0, 12.0),
}


# 时钟随普通尝试开始与重开重置；PAUSABLE 让 SceneTree 暂停冻结累计时间。
func configure(
	battle_attempt_flow: BattleAttemptFlow,
	bubble_dialogue_config: BubbleDialogueConfig,
	enqueue_dialogue_bubble: Callable
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
	_load_idle_ranges()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_battle_attempt_flow.attempt_started.connect(_on_attempt_started)
	_battle_attempt_flow.normal_combat_completed.connect(_on_normal_combat_completed)
	_battle_attempt_flow.attempt_failed.connect(_on_attempt_failed)
	_is_configured = true
	return true


# 本场重开也会发 attempt_started；重新读当前配置并清空旧计时与待提交条目。
func _on_attempt_started(
	_level: LevelProfile,
	_hit_resolution: HitResolution,
	_combat_stage: CombatStage,
	_repeat_queue: RepeatDelayQueue
) -> void:
	_attempt_active = true
	_elapsed_seconds = 0.0
	_idle_remaining.clear()
	for side: int in [BubbleDialogueEntry.SpeakerSide.PLAYER, BubbleDialogueEntry.SpeakerSide.OPPONENT]:
		_idle_remaining[side] = _roll_idle_interval(side)


# 两侧按06表已有独立范围调度；评论对白使用 random_weight 加权抽取。
func _process(delta: float) -> void:
	if not _attempt_active:
		return
	_elapsed_seconds += delta
	for side: int in _idle_remaining.keys():
		_idle_remaining[side] = float(_idle_remaining[side]) - delta
		if float(_idle_remaining[side]) > 0.0:
			continue
		if side == BubbleDialogueEntry.SpeakerSide.OPPONENT and _battle_attempt_flow.get_current_tier() <= CombatStage.INITIAL_TIER:
			continue
		var entry := _pick_idle_entry(side)
		if entry == null:
			_idle_remaining[side] = _roll_idle_interval(side)
			continue
		if bool(_enqueue_dialogue_bubble.call(entry)):
			_idle_remaining[side] = _roll_idle_interval(side)


func _pick_idle_entry(side: int) -> BubbleDialogueEntry:
	var candidates := _bubble_dialogue_config.find_by_event(TIMED_DIALOGUE_EVENT_ID, side)
	var total := 0.0
	for entry: BubbleDialogueEntry in candidates:
		total += maxf(0.0, entry.random_weight)
	if total <= 0.0:
		return null
	var target := randf() * total
	for entry: BubbleDialogueEntry in candidates:
		target -= maxf(0.0, entry.random_weight)
		if target <= 0.0:
			var chosen := entry.duplicate(true) as BubbleDialogueEntry
			chosen.priority = BubbleDialogueEntry.Priority.TIMED_IDLE
			return chosen
	return null


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


# 普通胜负结束计时，避免本场定时对白延续到 Paradox 或失败界面。
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
	_idle_remaining.clear()


# Sandbox 销毁时解除信号连接，避免旧尝试在后续场景中继续触发。
func _exit_tree() -> void:
	if not is_instance_valid(_battle_attempt_flow):
		return
	if _battle_attempt_flow.attempt_started.is_connected(_on_attempt_started):
		_battle_attempt_flow.attempt_started.disconnect(_on_attempt_started)
	if _battle_attempt_flow.normal_combat_completed.is_connected(_on_normal_combat_completed):
		_battle_attempt_flow.normal_combat_completed.disconnect(_on_normal_combat_completed)
	if _battle_attempt_flow.attempt_failed.is_connected(_on_attempt_failed):
		_battle_attempt_flow.attempt_failed.disconnect(_on_attempt_failed)
