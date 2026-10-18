extends Node2D

const BOARD_RECT: Rect2 = Rect2(Vector2(448.0, 72.0), Vector2(1024.0, 828.0))
const OPENING_NEUTRAL_COUNT: int = 30
const SEED_SLOT_COUNT: int = 2
const TEST_POPULATION_CAP: int = 44
const AUTOMATIC_POPULATION_LIMIT: int = TEST_POPULATION_CAP - 8
const ARRIVALS_TO_CHECK: int = 4
const BASE_SPAWN_INTERVAL_SECONDS: float = 0.12
const SPAWN_JITTER_RATIO: float = 0.25
const PHYSICS_TICKS_PER_SECOND: float = 60.0

var _simulation: PlanBUnitSimulation
var _failed_checks: Array[String] = []
var _arrival_frames: Array[int] = []
var _arrival_positions: Array[Vector2] = []


func _ready() -> void:
	call_deferred("_run_smoke")


## 检查30名开局中立、随机补人时序、固定seed重放和8颗批次空间。
func _run_smoke() -> void:
	var first_schedule: Array[int] = await _run_seeded_cycle(20261019)
	if not _failed_checks.is_empty():
		_finish_smoke()
		return
	var replayed_schedule: Array[int] = await _run_seeded_cycle(20261019)
	_check(first_schedule == replayed_schedule, "fixed seed replays the same arrival tick schedule")
	_finish_smoke()


## 每次用全新模拟器重放，避免前一局的棋子状态影响随机时序。
func _run_seeded_cycle(seed_value: int) -> Array[int]:
	await _discard_simulation()
	_simulation = PlanBUnitSimulation.new()
	_simulation.name = "Simulation"
	_simulation.position = BOARD_RECT.position
	add_child(_simulation)
	await get_tree().process_frame
	_simulation.maximum_population = TEST_POPULATION_CAP
	_simulation.initial_neutral_count = OPENING_NEUTRAL_COUNT
	_simulation.initial_seed_slot_count = SEED_SLOT_COUNT
	_simulation.neutral_spawn_interval_seconds = BASE_SPAWN_INTERVAL_SECONDS
	_simulation.neutral_spawn_jitter_ratio = SPAWN_JITTER_RATIO
	_simulation.lifespan_min_seconds = 120.0
	_simulation.lifespan_max_seconds = 120.0
	_simulation.base_speed_min = 1.0
	_simulation.base_speed_max = 1.0
	_simulation.maximum_speed = 1.0
	_simulation.set_random_seed(seed_value)
	_check(_simulation.set_play_area(BOARD_RECT), "simulation accepts the live board bounds")

	var created_ids: Array[int] = _simulation.create_population(-1, SEED_SLOT_COUNT)
	_check(
		created_ids.size() == OPENING_NEUTRAL_COUNT + SEED_SLOT_COUNT,
		"opening population creates 30 neutrals and two seed slots"
	)
	if created_ids.size() != OPENING_NEUTRAL_COUNT + SEED_SLOT_COUNT:
		return []
	_check(
		_simulation.seed_unit(created_ids[0], &"opponent", _word("seed_a", 1), 1),
		"first opponent seed succeeds"
	)
	_check(
		_simulation.seed_unit(created_ids[1], &"opponent", _word("seed_b", 1), 2),
		"second opponent seed succeeds"
	)
	_check(
		_simulation.get_faction_counts() == {"player": 0, "opponent": 2, "neutral": OPENING_NEUTRAL_COUNT},
		"opening faction census leaves exactly 30 neutral viewers"
	)
	_check_opening_positions_are_safe()
	_space_initial_units_for_isolated_spawn_checks()

	_arrival_frames.clear()
	_arrival_positions.clear()
	_simulation.unit_spawned.connect(_on_unit_spawned)
	var start_frame: int = Engine.get_physics_frames()
	_simulation.start_simulation()
	for _frame_index: int in 180:
		if _arrival_frames.size() >= ARRIVALS_TO_CHECK:
			break
		await get_tree().physics_frame
	_check(_arrival_frames.size() == ARRIVALS_TO_CHECK, "automatic arrivals reach the reserved capacity line")
	if _arrival_frames.size() != ARRIVALS_TO_CHECK:
		_simulation.pause_simulation()
		return []

	var schedule_frames: Array[int] = []
	var unique_intervals: Array[int] = []
	var previous_frame: int = start_frame
	var minimum_interval: float = maxf(
		BASE_SPAWN_INTERVAL_SECONDS * (1.0 - SPAWN_JITTER_RATIO),
		0.05
	)
	var maximum_interval: float = BASE_SPAWN_INTERVAL_SECONDS * (1.0 + SPAWN_JITTER_RATIO)
	for arrival_frame: int in _arrival_frames:
		var interval_frames: int = arrival_frame - previous_frame
		var interval_seconds: float = float(interval_frames) / PHYSICS_TICKS_PER_SECOND
		schedule_frames.append(interval_frames)
		if not unique_intervals.has(interval_frames):
			unique_intervals.append(interval_frames)
		_check(
			interval_seconds >= minimum_interval - 1.0 / PHYSICS_TICKS_PER_SECOND
			and interval_seconds <= maximum_interval + 1.0 / PHYSICS_TICKS_PER_SECOND,
			"arrival interval stays within the configured jitter range"
		)
		previous_frame = arrival_frame
	_check(unique_intervals.size() > 1, "jitter produces more than one interval in the fixed-seed sample")
	_check_spawn_positions_are_safe()
	_check(
		_simulation.get_unit_snapshots().size() == AUTOMATIC_POPULATION_LIMIT,
		"automatic arrivals stop eight seats below the actual population cap"
	)

	# 多等出两个以上基础间隔，确认预留线会暂停补人计时。
	for _frame_index: int in 24:
		await get_tree().physics_frame
	_check(
		_arrival_frames.size() == ARRIVALS_TO_CHECK
		and _simulation.get_unit_snapshots().size() == AUTOMATIC_POPULATION_LIMIT,
		"automatic replenishment stays paused while eight batch seats are reserved"
	)

	var batch_origin: Vector2 = BOARD_RECT.position + BOARD_RECT.size * 0.5
	var full_batch: Dictionary = _simulation.spawn_word_batch(
		batch_origin,
		&"player",
		_word("full_batch", 3),
		100,
		8
	)
	_check(bool(full_batch.get("ok", false)), "strength-three batch uses the eight reserved seats")
	_check(_simulation.get_unit_snapshots().size() == TEST_POPULATION_CAP, "full batch reaches the configured cap")
	var faction_counts: Dictionary = _simulation.get_faction_counts()
	_check(int(faction_counts.get("player", 0)) == 8, "published batch updates the actual player census")
	_check(_sum_factions(faction_counts) == TEST_POPULATION_CAP, "faction census matches actual population after batch")

	var population_before_rejection: int = _simulation.get_unit_snapshots().size()
	var rejected_batch: Dictionary = _simulation.spawn_word_batch(
		batch_origin,
		&"player",
		_word("over_capacity_batch", 1),
		101,
		2
	)
	_check(
		not bool(rejected_batch.get("ok", false))
		and str(rejected_batch.get("reason", "")) == "capacity",
		"actual population blocks a batch that exceeds the cap"
	)
	_check(
		_simulation.get_unit_snapshots().size() == population_before_rejection,
		"capacity rejection leaves the population unchanged"
	)
	_simulation.pause_simulation()
	return schedule_frames


## 校验开局随机位置和后续到场位置都为碰撞半径留出边界空间。
func _check_opening_positions_are_safe() -> void:
	var radius: float = _simulation.unit_collision_radius
	var minimum: Vector2 = BOARD_RECT.position + Vector2.ONE * radius
	var maximum: Vector2 = BOARD_RECT.end - Vector2.ONE * radius
	for snapshot: Dictionary in _simulation.get_unit_snapshots():
		var position: Vector2 = snapshot.get("position", Vector2(-1.0, -1.0))
		_check(
			position.x >= minimum.x and position.x <= maximum.x
			and position.y >= minimum.y and position.y <= maximum.y,
			"opening spawn respects the board collision margin"
		)


## 初始随机位置已经记录后将夹具棋子均匀摆开，隔离出生/容量行为与接触裁决。
func _space_initial_units_for_isolated_spawn_checks() -> void:
	var unit_index: int = 0
	for child: Node in _simulation.get_children():
		var unit := child as PlanBUnit
		if unit == null:
			continue
		var column: int = unit_index % 8
		var row: int = unit_index / 8
		unit.position = Vector2(64.0 + 128.0 * column, 80.0 + 220.0 * row)
		unit.collision_layer = 0
		unit.collision_mask = 0
		unit_index += 1


## 入场事件来自 B 的真实单位注册；每个新中立的位置使用场景全局坐标核对。
func _on_unit_spawned(unit_id: int) -> void:
	var snapshot: Dictionary = _simulation.get_unit_snapshot(unit_id)
	if str(snapshot.get("team", "")) != "neutral":
		return
	_arrival_frames.append(Engine.get_physics_frames())
	_arrival_positions.append(snapshot.get("position", Vector2(-1.0, -1.0)))
	var unit := _find_unit_node(unit_id)
	if unit != null:
		unit.collision_layer = 0
		unit.collision_mask = 0


## 按稳定 ID 找到实体节点，避免测试依赖模拟器内部字典。
func _find_unit_node(unit_id: int) -> PlanBUnit:
	for child: Node in _simulation.get_children():
		var unit := child as PlanBUnit
		if unit != null and unit.unit_id == unit_id:
			return unit
	return null


func _check_spawn_positions_are_safe() -> void:
	var radius: float = _simulation.unit_collision_radius
	var minimum: Vector2 = BOARD_RECT.position + Vector2.ONE * radius
	var maximum: Vector2 = BOARD_RECT.end - Vector2.ONE * radius
	for position: Vector2 in _arrival_positions:
		_check(
			position.x >= minimum.x and position.x <= maximum.x
			and position.y >= minimum.y and position.y <= maximum.y,
			"random arrival respects the board collision margin"
		)


func _word(word_id: String, strength: int) -> Dictionary:
	return {
		"word_id": word_id,
		"text": word_id,
		"battle_type": "type_a",
		"tendency": "neutral",
		"traits": [],
		"strength": strength,
	}


func _sum_factions(counts: Dictionary) -> int:
	return int(counts.get("player", 0)) + int(counts.get("opponent", 0)) + int(counts.get("neutral", 0))


func _discard_simulation() -> void:
	if _simulation == null:
		return
	_simulation.clear_population()
	_simulation.queue_free()
	await get_tree().process_frame
	_simulation = null


func _check(condition: bool, description: String) -> void:
	if condition:
		return
	_failed_checks.append(description)
	push_error("PB-15 smoke failed: %s" % description)


func _finish_smoke() -> void:
	if _simulation != null:
		_simulation.pause_simulation()
	if _failed_checks.is_empty():
		print("PB15_POPULATION_SMOKE_OK opening_neutral=30 seed_slots=2 replay=deterministic cap=44 batch=8")
		get_tree().quit(0)
		return
	push_error("PB-15 smoke failed checks: %s" % ", ".join(_failed_checks))
	get_tree().quit(1)
