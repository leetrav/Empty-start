extends Node2D

const TEST_PLAY_AREA: Rect2 = Rect2(Vector2.ZERO, Vector2(1920.0, 1080.0))

var _simulation: PlanBUnitSimulation
var _status_label: Label
var _markers: Dictionary = {}
var _contact_outcomes: Dictionary = {}
var _event_lines: Array[String] = []
var _spawned_count: int = 0
var _despawned_count: int = 0
var _failed: bool = false
var _motion_probe_ids: Dictionary = {}
var _motion_probe_summary: String = ""


func _ready() -> void:
	_simulation = get_node("Simulation") as PlanBUnitSimulation
	_simulation.unit_changed.connect(_on_unit_changed)
	_simulation.unit_spawned.connect(_on_unit_spawned)
	_simulation.unit_despawned.connect(_on_unit_despawned)
	_simulation.contact_resolved.connect(_on_contact_resolved)
	_create_preview_hud()
	call_deferred("_run_smoke")


func _process(_delta: float) -> void:
	var snapshots: Array[Dictionary] = _simulation.get_unit_snapshots()
	_sync_preview_markers(snapshots)
	_refresh_hud(snapshots)


## 通过真实 Area2D 重叠验证播种、改口、同属性弹开、感染和自然更新。
func _run_smoke() -> void:
	await _test_default_population_configuration()
	if _failed:
		return
	await _test_motion_intents_and_wall_bounce()
	if _failed:
		return
	await _test_same_team_relay()
	if _failed:
		return
	await _test_same_type_bounce()
	if _failed:
		return
	var first_conversion: Dictionary = await _run_counter_contact(20261017)
	var repeated_conversion: Dictionary = await _run_counter_contact(20261017)
	_check(first_conversion.get("outcome") == repeated_conversion.get("outcome"), "fixed seed repeats contact outcome")
	_check(first_conversion.get("target_team") == repeated_conversion.get("target_team"), "fixed seed repeats resulting faction")
	_check(first_conversion.get("outcome") == "converted", "counter type contact can infect at strength 3")
	if _failed:
		return
	await _test_neutral_infection()
	if _failed:
		return
	await _test_counterattack_split()
	if _failed:
		return
	await _test_neutral_replenishment()
	if _failed:
		return
	await _test_full_population_sample()
	if _failed:
		return
	_simulation.pause_simulation()
	_status_label.text = "PB-02 simulation smoke: PASS\n" + "\n".join(_event_lines)
	print("PB-02 PASS: Area2D relay, same-type bounce, fixed-seed infection, natural despawn and neutral replenishment")
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0)


## 默认候选人口按共享试算值建出 76 名路人和 2 个待播种目标。
func _test_default_population_configuration() -> void:
	await _reset_simulation(169)
	var ids: Array[int] = _simulation.create_population()
	var counts: Dictionary = _simulation.get_faction_counts()
	var first_snapshot: Dictionary = _simulation.get_unit_snapshot(ids[0])
	_check(ids.size() == 78, "default population creates 76 neutrals plus 2 seed slots")
	_check(int(counts.get("neutral", 0)) == 78, "seed slots remain neutral until A seeds them")
	_check(_simulation.maximum_population == 96, "prototype population ceiling is 96")
	_check(_simulation.get_neutral_unit_ids().size() == 78, "host can query neutral unit IDs")
	_check(_simulation.get_unit_snapshot(ids[0]).get("unit_id") == ids[0], "host can query one read-only unit snapshot")
	_check(_simulation.get_neutral_unit_at(first_snapshot.get("position", Vector2.ZERO)) == ids[0], "host can pick a neutral at scene position")
	_check(first_snapshot.has("word_id") and first_snapshot.get("word_id") == "" and int(first_snapshot.get("word_order", -1)) == 0, "neutral snapshot explicitly has empty phrase identity")


## 新话接触旧信徒后整体传递，不更改两棋子的阵营数量。
func _test_same_team_relay() -> void:
	await _reset_simulation(171)
	var ids: Array[int] = _simulation.create_population(2, 0)
	var new_definition: Dictionary = _word("new", "新话", "type_a", 2)
	_check(_simulation.seed_unit(ids[0], &"player", new_definition, 2), "seed new player word")
	new_definition["text"] = "外部已经修改"
	_check(_simulation.seed_unit(ids[1], &"player", _word("old", "旧话", "type_c", 1), 1), "seed old player word")
	var exposed_snapshot: Dictionary = _find_snapshot(ids[0])
	exposed_snapshot["text"] = "UI 尝试修改"
	exposed_snapshot["traits"][0] = "mutated_trait"
	_check(_find_snapshot(ids[0]).get("text") == "新话", "seed and public snapshots are deep copies")
	_place_pair(ids[0], ids[1])
	_simulation.start_simulation()
	var outcome: String = await _wait_for_pair_outcome(ids[0], ids[1])
	var older_snapshot: Dictionary = _find_snapshot(ids[1])
	_check(outcome == "same_team_bounce", "same-team contact bounces")
	_check(older_snapshot.get("word_id") == "new" and int(older_snapshot.get("word_order", 0)) == 2, "newer phrase snapshot relays to older follower")
	_check(_simulation.get_faction_counts() == {"player": 2, "opponent": 0, "neutral": 0}, "relay leaves faction counts unchanged")


## 同属性敌我接触只弹开；strength 3 不能越过类型合法性检查。
func _test_same_type_bounce() -> void:
	await _reset_simulation(172)
	var ids: Array[int] = _simulation.create_population(2, 0)
	_simulation.seed_unit(ids[0], &"player", _word("player-a", "玩家同类", "type_a", 3), 1)
	_simulation.seed_unit(ids[1], &"opponent", _word("opponent-a", "对手同类", "type_a", 3), 2)
	_place_pair(ids[0], ids[1])
	_simulation.start_simulation()
	var outcome: String = await _wait_for_pair_outcome(ids[0], ids[1])
	var second_snapshot: Dictionary = _find_snapshot(ids[1])
	_check(outcome == "same_type_bounce", "same-type enemy contact bounces")
	_check(second_snapshot.get("team") == "opponent" and second_snapshot.get("word_id") == "opponent-a", "same-type contact preserves opponent snapshot")
	_check(_simulation.get_faction_counts() == {"player": 1, "opponent": 1, "neutral": 0}, "same-type contact preserves team counts")


## 三种意图用不同目标触发；游荡者接近真实边界后反射回场内。
func _test_motion_intents_and_wall_bounce() -> void:
	await _reset_simulation(170)
	var ids: Array[int] = _simulation.create_population(5, 0)
	_motion_probe_ids = {"chase": ids[0], "flee": ids[2], "wander": ids[4]}
	_simulation.seed_unit(ids[0], &"player", _word("chaser", "追逐者", "type_a", 2), 1)
	_simulation.seed_unit(ids[1], &"opponent", _word("prey", "被追者", "type_b", 2), 2)
	_simulation.seed_unit(ids[2], &"player", _word("runner", "逃跑者", "type_a", 2), 3)
	_simulation.seed_unit(ids[3], &"opponent", _word("threat", "克制者", "type_c", 2), 4)
	_set_unit_position(ids[0], Vector2(400.0, 300.0))
	_set_unit_position(ids[1], Vector2(520.0, 300.0))
	_set_unit_position(ids[2], Vector2(400.0, 700.0))
	_set_unit_position(ids[3], Vector2(520.0, 700.0))
	_set_unit_position(ids[4], Vector2(1700.0, 900.0))
	_simulation.start_simulation()
	for frame_index: int in 3:
		await get_tree().physics_frame
	_check(_find_snapshot(ids[0]).get("motion_intent") == "chase", "counterable enemy triggers chase intent")
	_check(_find_snapshot(ids[2]).get("motion_intent") == "flee", "countering enemy triggers flee intent")
	_check(_find_snapshot(ids[4]).get("motion_intent") == "wander", "unthreatened neutral keeps wander intent")
	_motion_probe_summary = "Motion check: chase #%d  |  flee #%d  |  wander #%d" % [ids[0], ids[2], ids[4]]
	var wall_unit := _find_unit_node(ids[4])
	wall_unit.position = Vector2(1898.0, 900.0)
	wall_unit.wander_direction = Vector2.RIGHT
	wall_unit.wander_change_remaining = 10.0
	wall_unit.base_speed = _simulation.maximum_speed
	for frame_index: int in 12:
		await get_tree().physics_frame
	var wall_snapshot: Dictionary = _find_snapshot(ids[4])
	_check(float(wall_snapshot.get("position", Vector2.ZERO).x) <= TEST_PLAY_AREA.end.x - _simulation.unit_collision_radius + 0.01, "wall bounce clamps the unit to the play area")
	_check(float(wall_snapshot.get("velocity", Vector2.ZERO).x) < 0.0, "wall bounce reverses the outward velocity")


## 固定 seed 与接触几何相同，重复运行必须得到相同感染事实。
func _run_counter_contact(seed_value: int) -> Dictionary:
	await _reset_simulation(seed_value)
	var ids: Array[int] = _simulation.create_population(2, 0)
	_simulation.seed_unit(ids[0], &"player", _word("counter", "可克制话", "type_a", 3), 1)
	_simulation.seed_unit(ids[1], &"opponent", _word("weak", "被克制话", "type_b", 1), 2)
	_place_pair(ids[0], ids[1])
	_simulation.start_simulation()
	var outcome: String = await _wait_for_pair_outcome(ids[0], ids[1])
	var second_snapshot: Dictionary = _find_snapshot(ids[1])
	return {"outcome": outcome, "target_team": str(second_snapshot.get("team", "")), "snapshot": second_snapshot}


## 有感染能力的阵营棋子也使用强度概率转换中立观众；路人自身不能发起感染。
func _test_neutral_infection() -> void:
	await _reset_simulation(20261017)
	var ids: Array[int] = _simulation.create_population(2, 0)
	_simulation.seed_unit(ids[0], &"player", _word("roadside", "传话路人", "type_a", 3), 1)
	_place_pair(ids[0], ids[1])
	_simulation.start_simulation()
	var outcome: String = await _wait_for_pair_outcome(ids[0], ids[1])
	var neutral_snapshot: Dictionary = _find_snapshot(ids[1])
	_check(outcome == "converted", "faction unit infects neutral on a successful strength roll")
	_check(neutral_snapshot.get("team") == "player" and neutral_snapshot.get("word_id") == "roadside", "neutral receives complete infecting word snapshot")


## C 的 alien_t3_split 请求由 B 创建两个新对手棋子，并继承目标的完整当前话语快照。
func _test_counterattack_split() -> void:
	await _reset_simulation(175)
	_simulation.maximum_population = 4
	_simulation.neutral_spawn_interval_seconds = 100.0
	var ids: Array[int] = _simulation.create_population(2, 0)
	_simulation.seed_unit(ids[0], &"opponent", _word("split-source", "费米分裂话", "type_b", 2), 7)
	_simulation.start_simulation()
	var source_snapshot: Dictionary = _simulation.get_unit_snapshot(ids[0])
	var spawned_before: int = _spawned_count
	var request: Dictionary = {
		"skill_id": "alien_t3_split",
		"target_unit_id": str(ids[0]),
		"effect_id": &"split",
		"effect_parameters": {"child_count": 2},
	}
	_check(_simulation.apply_counterattack_effect(request), "C split request applies through B public effect API")
	var faction_counts: Dictionary = _simulation.get_faction_counts()
	var snapshots: Array[Dictionary] = _simulation.get_unit_snapshots()
	var copied_children: Array[Dictionary] = []
	for snapshot: Dictionary in snapshots:
		if snapshot.get("team") == "opponent" and int(snapshot.get("unit_id", -1)) != ids[0]:
			copied_children.append(snapshot)
	_check(copied_children.size() == 2, "split effect creates two additional opponent units")
	_check(int(faction_counts.get("opponent", 0)) == 3 and int(faction_counts.get("neutral", 0)) == 1, "split updates only real unit counts")
	_check(_spawned_count == spawned_before + 2, "split reports both children through unit_spawned")
	for child_snapshot: Dictionary in copied_children:
		_check(
			child_snapshot.get("word_id") == source_snapshot.get("word_id")
			and child_snapshot.get("text") == source_snapshot.get("text")
			and child_snapshot.get("word_order") == source_snapshot.get("word_order")
			and child_snapshot.get("battle_type") == source_snapshot.get("battle_type")
			and child_snapshot.get("strength") == source_snapshot.get("strength")
			and child_snapshot.get("traits") == source_snapshot.get("traits")
			and child_snapshot.get("tendency") == source_snapshot.get("tendency")
			and child_snapshot.get("position") != source_snapshot.get("position"),
			"split child inherits complete opponent word state"
		)
	_check(not _simulation.apply_counterattack_effect(request), "split refuses when the configured population ceiling is full")


## 在上限 96 的密度下连续推进固定物理帧，日志记录实际帧时长供原型调参。
func _test_full_population_sample() -> void:
	await _reset_simulation(174)
	_simulation.maximum_population = 96
	_simulation.neutral_spawn_interval_seconds = 100.0
	_simulation.lifespan_min_seconds = 120.0
	_simulation.lifespan_max_seconds = 120.0
	var ids: Array[int] = _simulation.create_population(96, 0)
	_check(ids.size() == 96, "simulation accepts the full 96-unit candidate population")
	_simulation.seed_unit(ids[0], &"player", _word("stress-player", "玩家样本", "type_a", 2), 1)
	_simulation.seed_unit(ids[1], &"opponent", _word("stress-opponent", "对手样本", "type_b", 2), 2)
	_simulation.start_simulation()
	var frame_count: int = 180
	var start_usec: int = Time.get_ticks_usec()
	for frame_index: int in frame_count:
		await get_tree().physics_frame
	var elapsed_msec: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	var mean_frame_msec: float = elapsed_msec / float(frame_count)
	print("PB-02 PERF: population=96 physics_frames=%d wall_ms=%.1f mean_ms_per_tick=%.2f reported_fps=%.1f" % [
		frame_count,
		elapsed_msec,
		mean_frame_msec,
		Engine.get_frames_per_second(),
	])
	_check(_simulation.get_unit_snapshots().size() == 96, "full population remains bounded after motion sample")


## 棋子离场后以新 unit_id 补入中立路人，不会把现有信徒重置为中立。
func _test_neutral_replenishment() -> void:
	await _reset_simulation(173)
	_simulation.maximum_population = 3
	_simulation.neutral_spawn_interval_seconds = 0.05
	_simulation.lifespan_min_seconds = 0.08
	_simulation.lifespan_max_seconds = 0.08
	var ids: Array[int] = _simulation.create_population(2, 0)
	var spawned_before: int = _spawned_count
	var despawned_before: int = _despawned_count
	_simulation.start_simulation()
	for frame_index: int in 24:
		await get_tree().physics_frame
	var counts: Dictionary = _simulation.get_faction_counts()
	_check(_despawned_count >= despawned_before + ids.size(), "natural lifespan emits despawn facts")
	_check(_spawned_count > spawned_before + ids.size(), "vacant population receives newly spawned unit")
	_check(int(counts.get("player", 0)) == 0 and int(counts.get("opponent", 0)) == 0, "natural refill does not mutate faction units")


func _reset_simulation(seed_value: int) -> void:
	_simulation.pause_simulation()
	_simulation.clear_battle()
	await get_tree().process_frame
	_simulation.maximum_population = 96
	_simulation.neutral_spawn_interval_seconds = 100.0
	_simulation.lifespan_min_seconds = 60.0
	_simulation.lifespan_max_seconds = 60.0
	_simulation.unit_collision_radius = 13.0
	_simulation.set_play_area(TEST_PLAY_AREA)
	_simulation.set_type_counter_map({"type_a": "type_b", "type_b": "type_c", "type_c": "type_a"})
	_simulation.set_random_seed(seed_value)
	_contact_outcomes.clear()


func _place_pair(first_id: int, second_id: int) -> void:
	_set_unit_position(first_id, Vector2(720.0, 420.0))
	_set_unit_position(second_id, Vector2(738.0, 420.0))


func _set_unit_position(unit_id: int, new_position: Vector2) -> void:
	var unit := _find_unit_node(unit_id)
	if unit != null:
		unit.position = new_position


func _find_unit_node(unit_id: int) -> PlanBUnit:
	for child: Node in _simulation.get_children():
		var unit := child as PlanBUnit
		if unit != null and unit.unit_id == unit_id:
			return unit
	return null


func _wait_for_pair_outcome(first_id: int, second_id: int) -> String:
	var pair := Vector2i(mini(first_id, second_id), maxi(first_id, second_id))
	for frame_index: int in 12:
		if _contact_outcomes.has(pair):
			return str(_contact_outcomes[pair])
		await get_tree().physics_frame
	return "no-contact"


func _find_snapshot(unit_id: int) -> Dictionary:
	for snapshot: Dictionary in _simulation.get_unit_snapshots():
		if int(snapshot.get("unit_id", -1)) == unit_id:
			return snapshot
	return {}


func _word(word_id: String, text: String, battle_type: String, strength: int) -> Dictionary:
	return {
		"word_id": word_id,
		"text": text,
		"battle_type": battle_type,
		"strength": strength,
		"traits": ["test_trait"],
		"tendency": "neutral",
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		_status_label.text = "PB-02 simulation smoke: FAIL\n" + message
		push_error("PB-02 FAIL: " + message)
		get_tree().quit(1)
		return
	print("PB-02 CHECK: " + message)
	_event_lines.append("✓ " + message)
	if _event_lines.size() > 6:
		_event_lines.pop_front()


func _on_unit_changed(unit_id: int, reason: StringName) -> void:
	var message := "unit %d %s" % [unit_id, str(reason)]
	print("PB-02 EVENT: " + message)
	_event_lines.append(message)
	if _event_lines.size() > 6:
		_event_lines.pop_front()


func _on_unit_spawned(_unit_id: int) -> void:
	_spawned_count += 1
	if _simulation.is_running():
		_record_visible_event("unit_spawned %d neutral" % _unit_id)


func _on_unit_despawned(_unit_id: int) -> void:
	_despawned_count += 1
	if _simulation.is_running():
		_record_visible_event("unit_despawned %d" % _unit_id)


func _on_contact_resolved(first_unit_id: int, second_unit_id: int, outcome: StringName) -> void:
	var pair := Vector2i(mini(first_unit_id, second_unit_id), maxi(first_unit_id, second_unit_id))
	_contact_outcomes[pair] = str(outcome)
	if outcome == &"neutral_bounce":
		return
	var message := "contact %d/%d %s" % [first_unit_id, second_unit_id, str(outcome)]
	_record_visible_event(message)


func _record_visible_event(message: String) -> void:
	print("PB-02 EVENT: " + message)
	_event_lines.append(message)
	if _event_lines.size() > 6:
		_event_lines.pop_front()


func _create_preview_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_status_label = Label.new()
	_status_label.position = Vector2(32.0, 24.0)
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_color", Color(0.93, 0.95, 1.0))
	_status_label.text = "PB-02 real Area2D contact preview"
	canvas.add_child(_status_label)
	set_meta("preview_canvas", canvas)


func _sync_preview_markers(snapshots: Array[Dictionary]) -> void:
	var canvas := get_meta("preview_canvas") as CanvasLayer
	if canvas == null:
		return
	var active_ids: Dictionary = {}
	for snapshot: Dictionary in snapshots:
		var unit_id: int = int(snapshot.get("unit_id", -1))
		active_ids[unit_id] = true
		var marker := _markers.get(unit_id) as ColorRect
		if marker == null:
			marker = ColorRect.new()
			marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			canvas.add_child(marker)
			_markers[unit_id] = marker
		var team: String = str(snapshot.get("team", "neutral"))
		var marker_size: Vector2 = Vector2(20.0, 20.0) if team != "neutral" else Vector2(9.0, 9.0)
		marker.size = marker_size
		marker.position = snapshot.get("position", Vector2.ZERO) - marker_size * 0.5
		marker.color = _team_color(team)
	for marker_id: Variant in _markers.keys():
		if active_ids.has(marker_id):
			continue
		var stale_marker := _markers[marker_id] as ColorRect
		if is_instance_valid(stale_marker):
			stale_marker.queue_free()
		_markers.erase(marker_id)


func _team_color(team: String) -> Color:
	match team:
		"player":
			return Color(0.22, 0.78, 0.96)
		"opponent":
			return Color(0.98, 0.35, 0.34)
		_:
			return Color(0.54, 0.60, 0.69)


func _refresh_hud(snapshots: Array[Dictionary]) -> void:
	if _status_label == null:
		return
	var counts: Dictionary = _simulation.get_faction_counts()
	var snapshots_by_id: Dictionary = {}
	for snapshot: Dictionary in snapshots:
		snapshots_by_id[int(snapshot.get("unit_id", -1))] = snapshot
	var intent_labels: Array[String] = []
	for intent: String in ["chase", "flee", "wander"]:
		var probe_id: int = int(_motion_probe_ids.get(intent, -1))
		var probe_snapshot: Dictionary = snapshots_by_id.get(probe_id, {})
		if not probe_snapshot.is_empty():
			intent_labels.append("%s #%d=%s" % [intent.to_upper(), probe_id, str(probe_snapshot.get("motion_intent", ""))])
	var header := "PB-02 Area2D preview  |  player %d  opponent %d  neutral %d  |  total %d" % [
		int(counts.get("player", 0)),
		int(counts.get("opponent", 0)),
		int(counts.get("neutral", 0)),
		snapshots.size(),
	]
	var intent_line: String = _motion_probe_summary if not _motion_probe_summary.is_empty() else "MOTION  " + "  |  ".join(intent_labels)
	_status_label.text = header + "\n" + intent_line + "\n" + "\n".join(_event_lines)
