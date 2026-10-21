extends Control

const PLAN_B_SCENE: PackedScene = preload("res://scenes/sandbox/sandbox_plan_b.tscn")
const CONSUMER_SCRIPT: Script = preload("res://data/shared/formal_sheet_runtime_consumer.gd")

const EVENT_CONNECTED: StringName = &"combat_connected"
const EVENT_TIER_UP: StringName = &"combat_tier_up"
const EVENT_HIT_ANY: StringName = &"opponent_hit_any"
const EVENT_TIMED: StringName = &"timed"
const EVENT_PARADOX_ENTER: StringName = &"paradox_enter"

var _failures: Array[String] = []
var _checks: int = 0
var _sandbox: Node
var _host: Node
var _hud: Node
var _dialogue_queue: Node
var _flow: Node
var _story_config: BubbleDialogueConfig
var _bubble_stacks: Array[StreamerBubbleStack] = []
var _tracked_bubble_ids: Dictionary = {}
var _displayed_entries: Array[Dictionary] = []
var _completed_events: Array[Dictionary] = []
var _presented_bubbles: int = 0
var _expired_bubbles: int = 0
var _last_publish_ok: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run_smoke()


func _run_smoke() -> void:
	seed(20261021)
	SaveManager.new_game()
	SaveManager.data.next_normal_level_order = 1
	SaveManager.data.completed_normal_level_ids = []
	var completed_tutorial_steps: Array[String] = [
		"pb25_v2_intro_publish", "pb25_v2_first_counterattack",
		"pb25_v2_paper_s1_invasion", "pb25_v2_paper_conversion_success",
		"pb25_v2_second_counterattack", "pb25_v2_contradiction_break",
	]
	SaveManager.data.completed_tutorial_step_ids = completed_tutorial_steps
	_check_formal_table_binding()

	_sandbox = PLAN_B_SCENE.instantiate()
	add_child(_sandbox)
	var ready := await _wait_until(Callable(self, "_is_level_one_ready"), 12.0)
	_check(ready, "正式 Plan B Sandbox 从 20 表绑定到 level_001 / story_level_001")
	if not ready:
		var failed_flow: Node = _sandbox.call("get_battle_attempt_flow") as Node
		var failed_level: LevelProfile = null
		var failed_active: bool = false
		if failed_flow != null:
			failed_level = failed_flow.call("get_current_level_profile") as LevelProfile
			failed_active = bool(failed_flow.call("is_normal_combat_active"))
		print("SANDBOX_START_DIAGNOSTIC level=%s active=%s" % [
			failed_level.level_id if failed_level != null else "<missing>",
			failed_active])
		_finish()
		return

	_flow = _sandbox.call("get_battle_attempt_flow") as Node
	_host = _sandbox.call("get_plan_b_battle_host") as Node
	_hud = _sandbox.call("get_plan_b_battle_ui") as Node
	_dialogue_queue = _hud.get_node_or_null("BubbleDialogueQueue") if _hud != null else null
	_story_config = CONSUMER_SCRIPT.new().call(
		"create_dialogue_config", "story_level_001") as BubbleDialogueConfig
	_bubble_stacks = _find_bubble_stacks()
	_check(_flow != null and _host != null and _hud != null
		and _bubble_stacks.size() == 2,
		"真实 Sandbox 提供 BattleAttemptFlow、Host 与双方主播气泡栈")
	if _flow == null or _host == null or _hud == null or _bubble_stacks.size() != 2:
		_finish()
		return

	_hud.connect("dialogue_bubble_presented", Callable(self, "_on_dialogue_bubble_presented"))
	_hud.connect("dialogue_sequence_completed", Callable(self, "_on_hud_sequence_completed"))
	if _dialogue_queue != null:
		_dialogue_queue.connect("sequence_completed", Callable(self, "_on_queue_sequence_completed"))
	_sandbox.connect("dialogue_event_sequence_completed", Callable(self, "_on_event_sequence_completed"))
	for stack: StreamerBubbleStack in _bubble_stacks:
		stack.child_entered_tree.connect(Callable(self, "_on_bubble_entered"))
	_host.connect("publish_result", Callable(self, "_on_publish_result"))
	var live_config: BubbleDialogueConfig = _sandbox.get("_active_dialogue_config") as BubbleDialogueConfig
	print("LIVE_CONFIG entries=%d connected=%d t2=%d" % [
		live_config.entries.size(),
		live_config.find_by_event(&"combat_connected").size(),
		live_config.find_by_event(&"combat_tier_up_t2").size()])
	# 关闭自然 PK 速率并加快 UI Tween；阶段仍经 Host 的正式调试入口变化。
	_host.set("pk_rate_pp_per_second", 0.0)
	Engine.time_scale = 4.0

	var connect_status: Dictionary = _sandbox.call("debug_set_player_pk_with_status", 0.64)
	_check(bool(connect_status.get("ok", false)) and int(connect_status.get("tier", -1)) == 2,
		"经 Sandbox/Host 正式 PK 更新从 T0 连线并跨入 T2")
	print("WAIT_CONNECTED paused=%s" % get_tree().paused)
	var connected_done := await _wait_until(
		func() -> bool: return _event_count(EVENT_CONNECTED) >= 1, 14.0)
	print("WAIT_CONNECTED_DONE value=%s paused=%s" % [connected_done, get_tree().paused])
	_check(connected_done, "连线序列逐句展示并在最后一只气泡退场后完成")
	var tier_two_done := await _wait_until(
		func() -> bool: return _event_count(EVENT_TIER_UP) >= 1, 14.0)
	_check(tier_two_done, "T2 多句剧本在连线开场完成后按 line_order 顺序出现")
	_check(_connected_precedes_tier_two(), "T2 对白的第一行晚于完整连线序列")
	_check(_tier_two_order_is_preserved(), "费米 T2 对手三句按 1→2→3 顺序展示")

	var hit_triggered := false
	if _event_count(EVENT_HIT_ANY) == 0:
		var opponent_position: Variant = await _wait_for_opponent_position(5.0)
		var card: Dictionary = _find_available_player_card()
		if opponent_position != null and not card.is_empty():
			_hud.emit_signal(
				"publish_requested",
				int(card.get("slot_id", -1)),
				str(card.get("word_id", "")),
				opponent_position)
			await get_tree().process_frame
			_check(_last_publish_ok, "通过正式 HUD/Host 发表入口生成玩家棋子")
			hit_triggered = await _wait_until(
				func() -> bool: return _event_count(EVENT_HIT_ANY) >= 1, 10.0)
	_check(hit_triggered or _event_count(EVENT_HIT_ANY) >= 1,
		"玩家正式发表与对手棋子发生真实接触后触发通用受击台词")

	var idle_seen := await _wait_until(
		func() -> bool: return _opponent_random_idle_count() > 0, 18.0)
	_check(idle_seen, "随机闲聊按 trigger_key 成组选取并实际展示一条对手对白")

	var max_status: Dictionary = _sandbox.call("debug_set_player_pk_with_status", 1.0)
	_check(bool(max_status.get("ok", false)), "正式 PK Host 接受最大值并进入普通胜利/矛盾流程")
	var paradox_entered := await _wait_until(
		func() -> bool:
			var oracle: Node = _sandbox.call("get_contradiction_oracle_flow") as Node
			return oracle != null and bool(oracle.call("is_contradiction_active")),
		12.0
	)
	_check(paradox_entered, "真实 ContradictionOracleFlow 进入矛盾阶段")
	var paradox_dialogue_done := await _wait_until(
		func() -> bool: return _event_count(EVENT_PARADOX_ENTER) >= 1, 16.0)
	_check(paradox_dialogue_done, "矛盾入场多句对白按表格行序播完")

	var bubbles_left := await _wait_until(
		func() -> bool: return _active_bubble_count() == 0 and _expired_bubbles >= _presented_bubbles,
		10.0
	)
	_check(bubbles_left, "已展示气泡全部发出 expired 并从主播栈退场")
	_check(_expired_bubbles == _presented_bubbles,
		"气泡创建/展示与真实退场计数一致：%d/%d" % [_presented_bubbles, _expired_bubbles])
	Engine.time_scale = 1.0
	_print_observation_summary()
	_finish()


func _check_formal_table_binding() -> void:
	var consumer: RefCounted = CONSUMER_SCRIPT.new() as RefCounted
	var expected_opponent_rows: Dictionary = {
		"story_level_001": 39,
		"story_level_002": 53,
		"story_level_003": 41,
		"story_level_004": 57,
	}
	for story_id: String in expected_opponent_rows:
		var config: BubbleDialogueConfig = consumer.call(
			"create_dialogue_config", story_id) as BubbleDialogueConfig
		var opponent_count: int = 0
		var tier_count: int = 0
		var idle_count: int = 0
		var hit_count: int = 0
		var paradox_count: int = 0
		for entry: BubbleDialogueEntry in config.entries:
			if entry.side != BubbleDialogueEntry.SpeakerSide.OPPONENT:
				continue
			opponent_count += 1
			if String(entry.event_id).begins_with("combat_tier_up_t"):
				tier_count += 1
			if entry.is_random_idle:
				idle_count += 1
			if entry.event_id == EVENT_HIT_ANY:
				hit_count += 1
			if entry.event_id == EVENT_PARADOX_ENTER:
				paradox_count += 1
		_check(opponent_count == int(expected_opponent_rows[story_id]),
			"%s 将启用 20 表记录绑定为 %d 条对手对白" % [story_id, opponent_count])
		_check(tier_count > 0 and idle_count > 0 and hit_count > 0 and paradox_count > 0,
			"%s 同时绑定 Tier、随机闲聊、受击及矛盾入场事件" % story_id)
		print("LOAD_BOUND story=%s opponent=%d tier=%d idle=%d hit=%d paradox=%d" % [
			story_id, opponent_count, tier_count, idle_count, hit_count, paradox_count])

	var level_three: BubbleDialogueConfig = consumer.call(
		"create_dialogue_config", "story_level_003") as BubbleDialogueConfig
	var tier_one: Array[BubbleDialogueEntry] = level_three.find_by_event(&"combat_tier_up_t1")
	var orders: Array[int] = []
	for entry: BubbleDialogueEntry in tier_one:
		orders.append(entry.line_order)
	_check(orders == [1, 2, 3, 4], "正式表 T1 双侧脚本保留全局 line_order")


func _is_level_one_ready() -> bool:
	if _sandbox == null:
		return false
	var flow: Node = _sandbox.call("get_battle_attempt_flow") as Node
	if flow == null or not bool(flow.call("is_normal_combat_active")):
		return false
	var level: LevelProfile = flow.call("get_current_level_profile") as LevelProfile
	return level != null and level.level_id == "level_001"


func _connected_precedes_tier_two() -> bool:
	var connected_index := _event_index(EVENT_CONNECTED)
	var tier_index := _event_index(EVENT_TIER_UP)
	return connected_index >= 0 and tier_index > connected_index


func _tier_two_order_is_preserved() -> bool:
	var observed_ids: Array[String] = []
	for record: Dictionary in _displayed_entries:
		if (str(record.get("event_id", "")) == "combat_tier_up_t2"
				and str(record.get("trigger_key", "")) == "T2"):
			observed_ids.append(str(record.get("dialogue_id", "")))
	var expected_ids: Array[String] = []
	var tier_entries: Array[BubbleDialogueEntry] = _story_config.find_by_event(&"combat_tier_up_t2")
	for entry: BubbleDialogueEntry in tier_entries:
		expected_ids.append(entry.dialogue_id)
	return observed_ids == expected_ids and expected_ids.size() == 3


func _find_available_player_card() -> Dictionary:
	var hand: Array = _host.call("get_player_hand")
	var states: Array = _host.call("get_player_slot_states")
	for card_value: Variant in hand:
		if not card_value is Dictionary:
			continue
		var card: Dictionary = card_value
		for state_value: Variant in states:
			if not state_value is Dictionary:
				continue
			var state: Dictionary = state_value
			if (int(state.get("slot_id", -1)) == int(card.get("slot_id", -2))
					and bool(state.get("available", false))
					and str(state.get("word_id", "")) == str(card.get("word_id", ""))):
				return card
	return {}


func _wait_for_opponent_position(timeout_seconds: float) -> Variant:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		for snapshot_value: Variant in _host.call("get_unit_snapshots"):
			if not snapshot_value is Dictionary:
				continue
			var snapshot: Dictionary = snapshot_value
			if (str(snapshot.get("team", "")) == "opponent"
					and snapshot.get("position", null) is Vector2):
				return snapshot.get("position")
		await get_tree().process_frame
	return null


func _on_publish_result(team: String, _word_id: String, result: Dictionary) -> void:
	if team == "player":
		_last_publish_ok = bool(result.get("ok", false))


func _on_dialogue_bubble_presented(side: int, event_id: StringName, text: String) -> void:
	_presented_bubbles += 1
	_track_existing_bubbles()
	var matched_entry: Resource
	for entry: BubbleDialogueEntry in _story_config.entries:
		if entry.text == text:
			matched_entry = entry
			break
	var record := {
		"side": side,
		"event_id": str(event_id),
		"dialogue_id": matched_entry.dialogue_id if matched_entry != null else "",
		"trigger_key": matched_entry.trigger_key if matched_entry != null else "",
		"line_order": matched_entry.line_order if matched_entry != null else 0,
		"observation_order": _presented_bubbles,
	}
	_displayed_entries.append(record)
	if side == BubbleDialogueEntry.SpeakerSide.OPPONENT:
		print("BUBBLE_PRESENT side=opponent id=%s event=%s key=%s order=%d" % [
			record["dialogue_id"], record["event_id"], record["trigger_key"], record["line_order"]])


func _on_bubble_entered(child: Node) -> void:
	if child is StreamerBubbleView:
		_track_bubble(child as StreamerBubbleView)


func _on_bubble_expired(_view: StreamerBubbleView) -> void:
	_expired_bubbles += 1


func _on_event_sequence_completed(event_id: StringName, sequence_id: StringName, side: int) -> void:
	_completed_events.append({
		"event_id": event_id,
		"sequence_id": sequence_id,
		"side": side,
		"observation_order": _presented_bubbles + _completed_events.size(),
	})
	print("BUBBLE_SEQUENCE_DONE event=%s id=%s side=%d" % [event_id, sequence_id, side])


func _on_hud_sequence_completed(sequence_id: StringName, side: int) -> void:
	print("HUD_SEQUENCE_DONE id=%s side=%d" % [sequence_id, side])


func _on_queue_sequence_completed(sequence_id: StringName, side: int) -> void:
	print("QUEUE_SEQUENCE_DONE id=%s side=%d" % [sequence_id, side])


func _event_count(event_id: StringName) -> int:
	var count: int = 0
	for record: Dictionary in _completed_events:
		if record.get("event_id") == event_id:
			count += 1
	return count


func _event_index(event_id: StringName) -> int:
	for index: int in range(_completed_events.size()):
		if _completed_events[index].get("event_id") == event_id:
			return index
	return -1


func _opponent_random_idle_count() -> int:
	var count: int = 0
	for record: Dictionary in _displayed_entries:
		if (int(record.get("side", -1)) == BubbleDialogueEntry.SpeakerSide.OPPONENT
				and str(record.get("event_id", "")) == String(EVENT_TIMED)):
			count += 1
	return count


func _active_bubble_count() -> int:
	return _find_bubble_views().size()


func _find_bubble_stacks() -> Array[StreamerBubbleStack]:
	var result: Array[StreamerBubbleStack] = []
	if _hud == null:
		return result
	for node: Node in _hud.find_children("*", "", true, false):
		if node is StreamerBubbleStack:
			result.append(node as StreamerBubbleStack)
	return result


func _find_bubble_views() -> Array[StreamerBubbleView]:
	var result: Array[StreamerBubbleView] = []
	if _hud == null:
		return result
	for node: Node in _hud.find_children("*", "", true, false):
		if node is StreamerBubbleView:
			result.append(node as StreamerBubbleView)
	return result


func _track_existing_bubbles() -> void:
	for bubble: StreamerBubbleView in _find_bubble_views():
		_track_bubble(bubble)


func _track_bubble(bubble: StreamerBubbleView) -> void:
	var bubble_id: int = bubble.get_instance_id()
	if _tracked_bubble_ids.has(bubble_id):
		return
	_tracked_bubble_ids[bubble_id] = true
	bubble.expired.connect(_on_bubble_expired)


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await get_tree().process_frame
	return bool(predicate.call())


func _print_observation_summary() -> void:
	print("DIALOGUE_SMOKE_SUMMARY shown=%d expired=%d events=%d active=%d" % [
		_presented_bubbles, _expired_bubbles, _completed_events.size(), _active_bubble_count()])
	for event_id: StringName in [EVENT_CONNECTED, EVENT_TIER_UP, EVENT_HIT_ANY, EVENT_TIMED, EVENT_PARADOX_ENTER]:
		print("DIALOGUE_SMOKE_EVENT id=%s completed=%d" % [event_id, _event_count(event_id)])


func _check(condition: bool, description: String) -> void:
	_checks += 1
	print(("PASS DIALOGUE_SMOKE: " if condition else "FAIL DIALOGUE_SMOKE: ") + description)
	if not condition:
		_failures.append(description)


func _finish() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(_sandbox):
		_sandbox.queue_free()
	await get_tree().process_frame
	print("DIALOGUE_SMOKE_RESULT checks=%d failures=%d" % [_checks, _failures.size()])
	get_tree().quit(1 if not _failures.is_empty() else 0)
