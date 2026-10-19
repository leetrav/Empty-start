extends Node2D

const BOARD_RECT: Rect2 = Rect2(Vector2(448.0, 72.0), Vector2(1024.0, 828.0))
const EXPECTED_RADIUS: float = 32.0
const EXPECTED_MINIMUM_SPACING: float = EXPECTED_RADIUS * 2.0 + 1.0

var _simulation: PlanBUnitSimulation
var _failed_checks: Array[String] = []
var _contact_outcomes: Array[StringName] = []
var _arrival_positions: Array[Vector2] = []


func _ready() -> void:
	call_deferred("_run_smoke")


## 单次核对PB-19开局、真实接触边界、棋盘安全区和完整批次。
func _run_smoke() -> void:
	_simulation = PlanBUnitSimulation.new()
	_simulation.name = "Simulation"
	_simulation.position = BOARD_RECT.position
	add_child(_simulation)
	await get_tree().process_frame
	_simulation.maximum_population = 96
	_simulation.initial_neutral_count = 30
	_simulation.initial_seed_slot_count = 0
	_simulation.neutral_spawn_interval_seconds = 100.0
	_simulation.lifespan_min_seconds = 120.0
	_simulation.lifespan_max_seconds = 120.0
	_simulation.set_random_seed(20261019)
	_check(is_equal_approx(_simulation.unit_collision_radius, EXPECTED_RADIUS), "default collision radius is 32px")
	_check(_simulation.set_play_area(BOARD_RECT), "simulation accepts the 1024x828 board bounds")
	_simulation.contact_resolved.connect(_on_contact_resolved)
	_check_opening_population()
	await _check_random_replenishment()
	_check_strength_batches()
	await _check_group_thresholds()
	await _check_contact_distance(63.0, true)
	await _check_contact_distance(65.0, false)
	_finish_smoke()


## 按正式A接口传入2个种子位，确认30中立与2个对手可用。
func _check_opening_population() -> void:
	var created_ids: Array[int] = _simulation.create_population(-1, 2)
	_check(created_ids.size() == 32, "opening population creates 30 neutral units and two seed slots")
	if created_ids.size() != 32:
		return
	var first_seeded: bool = _simulation.seed_unit(created_ids[0], &"opponent", _word("seed-1", 1), 1)
	var second_seeded: bool = _simulation.seed_unit(created_ids[1], &"opponent", _word("seed-2", 1), 2)
	_check(first_seeded and second_seeded, "both opening seed slots accept opponent units")
	_check(
		_simulation.get_faction_counts() == {"player": 0, "opponent": 2, "neutral": 30},
		"opening census is exactly 30 neutral and two opponents"
	)
	var minimum: Vector2 = BOARD_RECT.position + Vector2.ONE * EXPECTED_RADIUS
	var maximum: Vector2 = BOARD_RECT.end - Vector2.ONE * EXPECTED_RADIUS
	for snapshot: Dictionary in _simulation.get_unit_snapshots():
		var position: Vector2 = snapshot.get("position", Vector2(-1.0, -1.0))
		_check(
			position.x >= minimum.x and position.x <= maximum.x
			and position.y >= minimum.y and position.y <= maximum.y,
			"opening spawn stays within the 32px board margin"
		)
		_check(
			is_equal_approx(float(snapshot.get("collision_radius", 0.0)), EXPECTED_RADIUS),
			"unit snapshot reports the 32px collision radius"
		)
	for child: Node in _simulation.get_children():
		var unit := child as PlanBUnit
		if unit == null:
			continue
		unit.base_speed = 0.0
		unit.velocity = Vector2.ZERO
		unit.wander_direction = Vector2.ZERO
		unit.monitoring = false
		unit.collision_layer = 0
		unit.collision_mask = 0


## 运行一次自动补人周期，确认新位置沿用32px边界安全区。
func _check_random_replenishment() -> void:
	_arrival_positions.clear()
	_simulation.unit_spawned.connect(_on_unit_spawned)
	_simulation.neutral_spawn_interval_seconds = 0.12
	_simulation.neutral_spawn_jitter_ratio = 0.25
	_simulation.start_simulation()
	for _frame_index: int in 24:
		if not _arrival_positions.is_empty():
			break
		await get_tree().physics_frame
	_simulation.pause_simulation()
	_simulation.unit_spawned.disconnect(_on_unit_spawned)
	_check(not _arrival_positions.is_empty(), "random replenishment creates a neutral unit")
	var minimum: Vector2 = BOARD_RECT.position + Vector2.ONE * EXPECTED_RADIUS
	var maximum: Vector2 = BOARD_RECT.end - Vector2.ONE * EXPECTED_RADIUS
	for position: Vector2 in _arrival_positions:
		_check(
			position.x >= minimum.x and position.x <= maximum.x
			and position.y >= minimum.y and position.y <= maximum.y,
			"random arrival stays within the 32px board margin"
		)


## 逐个发2/4/8颗并核对新位置的边界和批次内安全间隔。
func _check_strength_batches() -> void:
	var centers: Array[Vector2] = [
		BOARD_RECT.position + Vector2(180.0, 120.0),
		BOARD_RECT.position + Vector2(520.0, 410.0),
		BOARD_RECT.position + Vector2(850.0, 700.0),
	]
	for batch_index: int in 3:
		var strength: int = batch_index + 1
		var expected_count: int = 1 << strength
		var result: Dictionary = _simulation.spawn_word_batch(
			centers[batch_index],
			&"player",
			_word("strength-%d" % strength, strength),
			100 + strength,
			expected_count
		)
		_check(bool(result.get("ok", false)), "strength %d complete batch succeeds" % strength)
		if not bool(result.get("ok", false)):
			continue
		var target_positions: Array = result.get("spawn_target_positions", [])
		_check(target_positions.size() == expected_count, "strength %d creates %d positions" % [strength, expected_count])
		var minimum: Vector2 = BOARD_RECT.position + Vector2.ONE * EXPECTED_RADIUS
		var maximum: Vector2 = BOARD_RECT.end - Vector2.ONE * EXPECTED_RADIUS
		for position_index: int in target_positions.size():
			var position: Vector2 = target_positions[position_index]
			_check(
				position.x >= minimum.x and position.x <= maximum.x
				and position.y >= minimum.y and position.y <= maximum.y,
				"strength %d batch position stays within the board margin" % strength
			)
			for previous_index: int in position_index:
				var previous_position: Vector2 = target_positions[previous_index]
				_check(
					position.distance_to(previous_position) >= EXPECTED_MINIMUM_SPACING - 0.01,
					"strength %d batch positions keep 65px spacing" % strength
				)
		for unit_id: Variant in result.get("unit_ids", []):
			var unit := _find_unit_node(int(unit_id))
			if unit == null:
				continue
			unit.monitoring = false
			unit.collision_layer = 0
			unit.collision_mask = 0


## 确认32px半径下同词棋子仍按72px加入、90px离开。
func _check_group_thresholds() -> void:
	_simulation.pause_simulation()
	_simulation.clear_population()
	await get_tree().process_frame
	var unit_ids: Array[int] = _simulation.create_population(2, 0)
	if unit_ids.size() != 2:
		_check(false, "group fixture creates two units")
		return
	var first_unit := _find_unit_node(unit_ids[0])
	var second_unit := _find_unit_node(unit_ids[1])
	if first_unit == null or second_unit == null:
		_check(false, "group fixture resolves both real unit nodes")
		return
	_simulation.seed_unit(unit_ids[0], &"player", _word("group", 1), 1)
	_simulation.seed_unit(unit_ids[1], &"player", _word("group", 1), 2)
	for unit: PlanBUnit in [first_unit, second_unit]:
		unit.base_speed = 0.0
		unit.velocity = Vector2.ZERO
		unit.wander_direction = Vector2.ZERO
		unit.wander_change_remaining = 100.0
		unit.monitoring = false
		unit.collision_layer = 0
		unit.collision_mask = 0
	var center: Vector2 = BOARD_RECT.get_center()
	first_unit.global_position = center + Vector2(-35.5, 0.0)
	second_unit.global_position = center + Vector2(35.5, 0.0)
	_simulation.start_simulation()
	var groups: Array[Dictionary] = _simulation.get_word_groups()
	_check(groups.size() == 1 and groups[0].get("member_ids", []).size() == 2, "71px neighbors join the same word group")
	second_unit.global_position = center + Vector2(49.5, 0.0)
	await _wait_physics_frames(18)
	groups = _simulation.get_word_groups()
	_check(groups.size() == 1 and groups[0].get("member_ids", []).size() == 2, "85px pair stays grouped inside the leave threshold")
	second_unit.global_position = center + Vector2(55.5, 0.0)
	await _wait_physics_frames(18)
	groups = _simulation.get_word_groups()
	_check(groups.size() == 2, "91px pair leaves the shared group")
	_simulation.pause_simulation()


## 用真实Area2D物理信号检查63px接触和65px分离边界。
func _check_contact_distance(center_distance: float, should_contact: bool) -> void:
	_simulation.pause_simulation()
	_simulation.clear_population()
	await get_tree().process_frame
	var unit_ids: Array[int] = _simulation.create_population(2, 0)
	_check(unit_ids.size() == 2, "contact fixture creates two units")
	if unit_ids.size() != 2:
		return
	var first_unit := _find_unit_node(unit_ids[0])
	var second_unit := _find_unit_node(unit_ids[1])
	if first_unit == null or second_unit == null:
		_check(false, "contact fixture resolves both real unit nodes")
		return
	for unit: PlanBUnit in [first_unit, second_unit]:
		unit.base_speed = 0.0
		unit.velocity = Vector2.ZERO
		unit.wander_direction = Vector2.ZERO
		unit.wander_change_remaining = 100.0
		unit.monitoring = true
		unit.collision_layer = 1
		unit.collision_mask = 1
	var center: Vector2 = BOARD_RECT.get_center()
	first_unit.global_position = center + Vector2(-center_distance * 0.5, 0.0)
	second_unit.global_position = center + Vector2(center_distance * 0.5, 0.0)
	_contact_outcomes.clear()
	_simulation.start_simulation()
	for _frame_index: int in 12:
		if not _contact_outcomes.is_empty():
			break
		await get_tree().physics_frame
	if should_contact:
		_check(
			_contact_outcomes.size() == 1 and _contact_outcomes[0] == &"neutral_bounce",
			"63px center distance triggers one real contact decision"
		)
		var separated_distance: float = first_unit.global_position.distance_to(second_unit.global_position)
		_check(
			separated_distance >= EXPECTED_RADIUS * 2.0 + 0.5 - 0.01,
			"contact separates units to at least 64.5px"
		)
	else:
		_check(_contact_outcomes.is_empty(), "65px center distance produces no contact decision")
	_simulation.pause_simulation()


func _find_unit_node(unit_id: int) -> PlanBUnit:
	for child: Node in _simulation.get_children():
		var unit := child as PlanBUnit
		if unit != null and unit.unit_id == unit_id:
			return unit
	return null


## 等待指定数量的物理帧，让碰撞与团体拓扑按正式时序刷新。
func _wait_physics_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await get_tree().physics_frame


func _word(word_id: String, strength: int) -> Dictionary:
	return {
		"word_id": word_id,
		"text": word_id,
		"battle_type": "type_a",
		"tendency": "neutral",
		"traits": [],
		"strength": strength,
	}


func _on_contact_resolved(_first_id: int, _second_id: int, outcome: StringName) -> void:
	_contact_outcomes.append(outcome)


## 随机新生棋子保持静止，避免自动补人检查受到后续接触影响。
func _on_unit_spawned(unit_id: int) -> void:
	var snapshot: Dictionary = _simulation.get_unit_snapshot(unit_id)
	if str(snapshot.get("team", "")) != "neutral":
		return
	_arrival_positions.append(snapshot.get("position", Vector2(-1.0, -1.0)))
	var unit := _find_unit_node(unit_id)
	if unit == null:
		return
	unit.base_speed = 0.0
	unit.velocity = Vector2.ZERO
	unit.wander_direction = Vector2.ZERO
	unit.monitoring = false
	unit.collision_layer = 0
	unit.collision_mask = 0


func _check(condition: bool, description: String) -> void:
	if condition:
		return
	_failed_checks.append(description)
	push_error("PB19 collision smoke failed: " + description)


func _finish_smoke() -> void:
	if _failed_checks.is_empty():
		print("PB19_COLLISION_SMOKE_OK radius=32 opening=neutral30+opponent2 contact=63-hit/65-miss groups=72-join/90-leave batches=2/4/8")
		get_tree().quit(0)
		return
	printerr("PB19_COLLISION_SMOKE_FAIL count=%d" % _failed_checks.size())
	get_tree().quit(1)
