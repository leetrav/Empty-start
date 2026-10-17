## 管理本局观众棋子的播种、运动、接触裁决、自然离场和中立人口补充。
class_name PlanBUnitSimulation
extends Node2D

signal unit_changed(unit_id: int, reason: StringName)
signal unit_spawned(unit_id: int)
signal unit_despawned(unit_id: int)
signal contact_resolved(first_unit_id: int, second_unit_id: int, outcome: StringName)
signal simulation_started
signal simulation_paused

const UNIT_SCENE: PackedScene = preload("res://systems/plan_b/simulation/plan_b_unit.tscn")
const NEUTRAL_TEAM: StringName = &"neutral"
const PLAYER_TEAM: StringName = &"player"
const OPPONENT_TEAM: StringName = &"opponent"
const INFECTION_CHANCES_BY_STRENGTH: Dictionary = {
	1: 0.20,
	2: 0.35,
	3: 0.50,
}

@export_group("Audience Population")
@export_range(1, 512, 1) var maximum_population: int = 96
@export_range(0, 500, 1) var initial_neutral_count: int = 76
@export_range(0, 32, 1) var initial_seed_slot_count: int = 2
@export_range(0.05, 10.0, 0.05) var neutral_spawn_interval_seconds: float = 0.75
@export_range(1.0, 180.0, 0.5) var lifespan_min_seconds: float = 53.0
@export_range(1.0, 180.0, 0.5) var lifespan_max_seconds: float = 77.0

@export_group("Collision")
@export_range(2.0, 64.0, 1.0) var unit_collision_radius: float = 13.0
@export_range(0.0, 5.0, 0.05) var collision_cooldown_seconds: float = 0.7
@export_range(0.0, 120.0, 1.0) var contact_recoil_speed: float = 22.0

@export_group("Movement")
@export_range(1.0, 160.0, 1.0) var base_speed_min: float = 30.0
@export_range(1.0, 160.0, 1.0) var base_speed_max: float = 52.0
@export_range(1.0, 200.0, 1.0) var maximum_speed: float = 78.0
@export_range(1.0, 1000.0, 1.0) var detection_radius: float = 220.0
@export_range(0.0, 3.0, 0.05) var wandering_weight: float = 0.35
@export_range(0.0, 3.0, 0.05) var chase_weight: float = 1.0
@export_range(0.0, 3.0, 0.05) var flee_weight: float = 1.35
@export_range(0.0, 2.0, 0.05) var chase_speed_scale: float = 1.05
@export_range(0.0, 2.0, 0.05) var flee_speed_scale: float = 1.15
@export var play_area: Rect2 = Rect2()

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _units_by_id: Dictionary = {}
var _type_counter_by_type: Dictionary = {}
var _next_unit_id: int = 1
var _is_running: bool = false
var _spawn_elapsed_seconds: float = 0.0
var _pending_contact_pairs: Array[Vector2i] = []
var _pending_contact_lookup: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	# 默认使用当前 Viewport 的本地尺寸；嵌入战斗场景时由 A 注入实际中央区域。
	if play_area.size.x <= 0.0 or play_area.size.y <= 0.0:
		play_area = Rect2(Vector2.ZERO, get_viewport_rect().size)
	set_physics_process(false)


## 设置可替换的“战斗类型 -> 能克制的类型”测试表；正式属性名和方向由 C 注入。
func set_type_counter_map(counter_map: Dictionary) -> bool:
	var normalized_map: Dictionary = {}
	for source_value: Variant in counter_map.keys():
		var target_value: Variant = counter_map[source_value]
		var source_type := StringName(str(source_value).strip_edges())
		var target_type := StringName(str(target_value).strip_edges())
		if source_type == &"" or target_type == &"" or source_type == target_type:
			return false
		normalized_map[source_type] = target_type
	_type_counter_by_type = normalized_map
	return true


## 固定本局随机流；测试在创建棋子前调用，生产局可留空使用随机种子。
func set_random_seed(seed_value: int) -> void:
	_rng.seed = seed_value


## 设置模拟区相对本节点的实际场景坐标，所有棋子和碰撞均在这块区域中运行。
func set_play_area(area: Rect2) -> bool:
	if area.size.x <= unit_collision_radius * 2.0 or area.size.y <= unit_collision_radius * 2.0:
		return false
	play_area = area
	return true


## 创建中立人群及预留播种目标。预留目标先保持中立，由 A 读取 C 词语后调用 seed_unit。
func create_population(neutral_count: int = -1, seed_slot_count: int = -1) -> Array[int]:
	clear_population()
	var neutral_total: int = initial_neutral_count if neutral_count < 0 else maxi(neutral_count, 0)
	var reserved_total: int = initial_seed_slot_count if seed_slot_count < 0 else maxi(seed_slot_count, 0)
	var population_total: int = mini(neutral_total + reserved_total, maximum_population)
	var created_ids: Array[int] = []
	for index: int in population_total:
		var new_unit: PlanBUnit = _spawn_unit(NEUTRAL_TEAM, {}, 0, _random_spawn_position())
		created_ids.append(new_unit.unit_id)
	return created_ids


## 将一个现存中立观众改成首次信徒；验证失败不会改变棋子或发出事件。
func seed_unit(neutral_unit_id: int, team_value: StringName, word_definition: Dictionary, new_word_order: int) -> bool:
	var unit := _units_by_id.get(neutral_unit_id) as PlanBUnit
	var clean_team := StringName(str(team_value))
	var clean_definition: Dictionary = _copy_valid_word_definition(word_definition)
	if unit == null or unit.team != NEUTRAL_TEAM:
		return false
	if not _is_faction(clean_team) or clean_definition.is_empty() or new_word_order < 1:
		return false
	unit.apply_word_snapshot(clean_team, clean_definition, new_word_order)
	unit_changed.emit(unit.unit_id, &"seed")
	return true


## 执行 C 的原型反击请求；split 子体完整继承对手目标快照并受人口上限约束。
func apply_counterattack_effect(request: Dictionary) -> bool:
	if not _is_running or request.is_empty() or str(request.get("effect_id", "")) != "split":
		return false
	var target_id: int = _normalize_unit_id(request.get("target_unit_id", -1))
	var target_unit := _units_by_id.get(target_id) as PlanBUnit
	if target_unit == null or target_unit.team != OPPONENT_TEAM or not target_unit.has_word():
		return false
	var parameters_value: Variant = request.get("effect_parameters", {})
	if not (parameters_value is Dictionary):
		return false
	var effect_parameters: Dictionary = parameters_value
	var requested_child_count: int = maxi(int(effect_parameters.get("child_count", 0)), 0)
	var available_slots: int = maxi(maximum_population - _units_by_id.size(), 0)
	var spawned_count: int = mini(requested_child_count, available_slots)
	if spawned_count <= 0:
		return false
	var source_definition: Dictionary = target_unit.get_word_snapshot()
	var source_team: StringName = target_unit.team
	var source_word_order: int = target_unit.word_order
	var spawned_any: bool = false
	for child_index: int in spawned_count:
		var spawn_position: Vector2 = _get_split_child_position(target_unit, child_index, spawned_count)
		var child_unit: PlanBUnit = _spawn_unit(
			source_team, source_definition, source_word_order, spawn_position
		)
		if child_unit != null:
			spawned_any = true
	return spawned_any


## 启动或恢复本地物理帧推进；棋子移动和碰撞由模块自身驱动。
func start_simulation() -> void:
	if _is_running:
		return
	_is_running = true
	set_physics_process(true)
	simulation_started.emit()


## 暂停棋子运动、生命周期、碰撞裁决和路人补充，保留所有运行状态。
func pause_simulation() -> void:
	if not _is_running:
		return
	_is_running = false
	set_physics_process(false)
	simulation_paused.emit()


## 清场并立即释放所属棋子，不依赖离树回调完成业务清理。
func clear_population() -> void:
	pause_simulation()
	_pending_contact_pairs.clear()
	_pending_contact_lookup.clear()
	_spawn_elapsed_seconds = 0.0
	var existing_ids: Array[int] = _get_sorted_unit_ids()
	for unit_id: int in existing_ids:
		var unit := _units_by_id.get(unit_id) as PlanBUnit
		_units_by_id.erase(unit_id)
		if is_instance_valid(unit):
			remove_child(unit)
			unit.queue_free()
		unit_despawned.emit(unit_id)


## PB-01 的清场入口；业务清理仍统一由本模拟模块拥有。
func clear_battle() -> void:
	clear_population()


## 供 A 以一个布尔值控制开始、暂停或恢复。
func set_active(active: bool) -> void:
	if active:
		start_simulation()
	else:
		pause_simulation()


## 按阵营重新统计实际棋子；PK 由 A 每帧读取本查询结果。
func get_faction_counts() -> Dictionary:
	var counts: Dictionary = {"player": 0, "opponent": 0, "neutral": 0}
	for unit_value: Variant in _units_by_id.values():
		var unit := unit_value as PlanBUnit
		if unit == null:
			continue
		var key := str(unit.team)
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


## 提供按 unit_id 排序的深拷贝，供 UI 绘制、交接和日志读取。
func get_unit_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for unit_id: int in _get_sorted_unit_ids():
		var unit := _units_by_id.get(unit_id) as PlanBUnit
		if unit != null:
			snapshots.append(unit.get_public_snapshot())
	return snapshots


## 返回单个棋子的只读深拷贝；找不到时返回空字典。
func get_unit_snapshot(unit_id: int) -> Dictionary:
	var unit := _units_by_id.get(unit_id) as PlanBUnit
	return unit.get_public_snapshot() if unit != null else {}


## 让 A / D 直接取得仍属中立的稳定 ID 列表，结果按 unit_id 排序。
func get_neutral_unit_ids() -> Array[int]:
	var neutral_ids: Array[int] = []
	for unit_id: int in _get_sorted_unit_ids():
		var unit := _units_by_id.get(unit_id) as PlanBUnit
		if unit != null and unit.team == NEUTRAL_TEAM:
			neutral_ids.append(unit_id)
	return neutral_ids


## 用实际全局场景坐标命中最近的中立棋子，未命中返回 -1。
func get_neutral_unit_at(scene_position: Vector2) -> int:
	var selected_id: int = -1
	var nearest_distance: float = unit_collision_radius
	for unit_id: int in get_neutral_unit_ids():
		var unit := _units_by_id.get(unit_id) as PlanBUnit
		if unit == null:
			continue
		var distance: float = unit.global_position.distance_to(scene_position)
		if distance <= nearest_distance:
			selected_id = unit_id
			nearest_distance = distance
	return selected_id


func is_running() -> bool:
	return _is_running


## 每个物理帧先裁决上一轮实际碰撞，再推进移动、寿命和补人。
func _physics_process(delta: float) -> void:
	_resolve_pending_contacts()
	_advance_units(delta)
	_despawn_expired_units()
	_update_neutral_replenishment(delta)


## 收集 Area2D 实际碰撞，双方的 entered 信号折叠为同一个无向棋子对。
func _on_unit_area_entered(other_area: Area2D, source_unit_id: int) -> void:
	var other_unit := other_area as PlanBUnit
	if other_unit == null or other_unit.unit_id == source_unit_id:
		return
	var pair := Vector2i(mini(source_unit_id, other_unit.unit_id), maxi(source_unit_id, other_unit.unit_id))
	if _pending_contact_lookup.has(pair):
		return
	_pending_contact_lookup[pair] = true
	_pending_contact_pairs.append(pair)


## 先按 ID 排序接触，再裁决，保证固定 seed 回放的抽样顺序稳定。
func _resolve_pending_contacts() -> void:
	if _pending_contact_pairs.is_empty():
		return
	var pairs: Array[Vector2i] = _pending_contact_pairs.duplicate()
	_pending_contact_pairs.clear()
	_pending_contact_lookup.clear()
	pairs.sort_custom(_pair_is_before)
	for pair: Vector2i in pairs:
		var first_unit := _units_by_id.get(pair.x) as PlanBUnit
		var second_unit := _units_by_id.get(pair.y) as PlanBUnit
		if first_unit == null or second_unit == null:
			continue
		_resolve_contact(first_unit, second_unit)


## 用棋子 ID 对接触对排序，避免物理 signal 的顺序影响随机判定结果。
func _pair_is_before(first_pair: Vector2i, second_pair: Vector2i) -> bool:
	if first_pair.x == second_pair.x:
		return first_pair.y < second_pair.y
	return first_pair.x < second_pair.x


## 冷却通过后先弹开，再按阵营、属性和注入克制表裁决一次。
func _resolve_contact(first_unit: PlanBUnit, second_unit: PlanBUnit) -> void:
	if first_unit.contact_cooldown_remaining > 0.0 or second_unit.contact_cooldown_remaining > 0.0:
		return
	first_unit.contact_cooldown_remaining = collision_cooldown_seconds
	second_unit.contact_cooldown_remaining = collision_cooldown_seconds
	_separate_and_recoil(first_unit, second_unit)

	if first_unit.team == second_unit.team:
		if first_unit.team == NEUTRAL_TEAM:
			contact_resolved.emit(first_unit.unit_id, second_unit.unit_id, &"neutral_bounce")
			return
		_relay_newer_word(first_unit, second_unit)
		contact_resolved.emit(first_unit.unit_id, second_unit.unit_id, &"same_team_bounce")
		return

	if first_unit.team == NEUTRAL_TEAM:
		_attempt_neutral_conversion(second_unit, first_unit)
		return
	if second_unit.team == NEUTRAL_TEAM:
		_attempt_neutral_conversion(first_unit, second_unit)
		return

	var first_counters_second: bool = _counters(first_unit, second_unit)
	var second_counters_first: bool = _counters(second_unit, first_unit)
	if first_unit.get_battle_type() == second_unit.get_battle_type():
		contact_resolved.emit(first_unit.unit_id, second_unit.unit_id, &"same_type_bounce")
		return
	if first_counters_second == second_counters_first:
		contact_resolved.emit(first_unit.unit_id, second_unit.unit_id, &"no_counter_bounce")
		return
	var infecting_unit: PlanBUnit = first_unit if first_counters_second else second_unit
	var receiving_unit: PlanBUnit = second_unit if first_counters_second else first_unit
	_attempt_conversion(infecting_unit, receiving_unit)


## 中立人群之间只发生物理弹开；阵营棋子可用当前话语强度尝试感染路人。
func _attempt_neutral_conversion(infecting_unit: PlanBUnit, neutral_unit: PlanBUnit) -> void:
	if infecting_unit.team == NEUTRAL_TEAM or not infecting_unit.has_word():
		contact_resolved.emit(infecting_unit.unit_id, neutral_unit.unit_id, &"neutral_bounce")
		return
	_attempt_conversion(infecting_unit, neutral_unit)


## strength 只作为合法感染的成功率，不参与移动、寿命、PK 或改口裁决。
func _attempt_conversion(infecting_unit: PlanBUnit, receiving_unit: PlanBUnit) -> void:
	var chance: float = float(INFECTION_CHANCES_BY_STRENGTH.get(infecting_unit.get_strength(), 0.0))
	if chance > 0.0 and _rng.randf() < chance:
		receiving_unit.apply_word_snapshot(
			infecting_unit.team,
			infecting_unit.get_word_snapshot(),
			infecting_unit.word_order
		)
		unit_changed.emit(receiving_unit.unit_id, &"convert")
		contact_resolved.emit(infecting_unit.unit_id, receiving_unit.unit_id, &"converted")
		return
	contact_resolved.emit(infecting_unit.unit_id, receiving_unit.unit_id, &"infection_failed")


## 同阵营接触必定由新 word_order 向旧棋子传播完整快照，人数和阵营保持原值。
func _relay_newer_word(first_unit: PlanBUnit, second_unit: PlanBUnit) -> void:
	var source_unit: PlanBUnit = first_unit if first_unit.word_order > second_unit.word_order else second_unit
	var receiving_unit: PlanBUnit = second_unit if source_unit == first_unit else first_unit
	if source_unit.word_order <= receiving_unit.word_order or not source_unit.has_word():
		return
	receiving_unit.apply_word_snapshot(source_unit.team, source_unit.get_word_snapshot(), source_unit.word_order)
	unit_changed.emit(receiving_unit.unit_id, &"relay")


## 将穿透式 Area2D 接触转为可见分离和反向速度，避免棋子粘连。
func _separate_and_recoil(first_unit: PlanBUnit, second_unit: PlanBUnit) -> void:
	var offset: Vector2 = first_unit.position - second_unit.position
	var minimum_distance: float = unit_collision_radius * 2.0
	var current_distance: float = offset.length()
	var normal: Vector2 = offset.normalized() if current_distance > 0.001 else Vector2.from_angle(_rng.randf_range(0.0, TAU))
	first_unit.wander_direction = normal
	second_unit.wander_direction = -normal
	if current_distance < minimum_distance:
		var separation: float = minimum_distance - current_distance + 0.5
		first_unit.position += normal * separation * 0.5
		second_unit.position -= normal * separation * 0.5
	if first_unit.velocity.dot(normal) < 0.0:
		first_unit.velocity = first_unit.velocity.bounce(normal)
	if second_unit.velocity.dot(-normal) < 0.0:
		second_unit.velocity = second_unit.velocity.bounce(-normal)
	first_unit.velocity += normal * contact_recoil_speed * 0.5
	second_unit.velocity -= normal * contact_recoil_speed * 0.5


## 游荡是默认意图；可感染目标进入追逐，可感染当前棋子的敌人优先触发逃跑。
func _advance_units(delta: float) -> void:
	var units: Array[PlanBUnit] = _get_sorted_units()
	var positions_by_id: Dictionary = {}
	for unit: PlanBUnit in units:
		positions_by_id[unit.unit_id] = unit.position
		unit.age_seconds += delta
		unit.contact_cooldown_remaining = maxf(unit.contact_cooldown_remaining - delta, 0.0)
		unit.wander_change_remaining -= delta
		if unit.wander_change_remaining <= 0.0:
			unit.wander_direction = Vector2.from_angle(_rng.randf_range(0.0, TAU))
			unit.wander_change_remaining = _rng.randf_range(1.2, 3.1)

	var steering_by_id: Dictionary = {}
	for unit: PlanBUnit in units:
		steering_by_id[unit.unit_id] = _get_steering(unit, units, positions_by_id)
	for unit: PlanBUnit in units:
		var steering: Dictionary = steering_by_id.get(unit.unit_id, {})
		var direction: Vector2 = steering.get("direction", unit.wander_direction)
		var intent: StringName = steering.get("intent", &"wander")
		unit.motion_intent = intent
		var speed_scale: float = 1.0
		if intent == &"chase":
			speed_scale = chase_speed_scale
		elif intent == &"flee":
			speed_scale = flee_speed_scale
		var applied_speed: float = minf(unit.base_speed * speed_scale, maximum_speed)
		unit.velocity = direction.normalized() * applied_speed if direction.length_squared() > 0.0001 else Vector2.ZERO
		unit.position += unit.velocity * delta
		_bounce_from_play_area(unit)


func _get_steering(unit: PlanBUnit, units: Array[PlanBUnit], positions_by_id: Dictionary) -> Dictionary:
	if unit.team == NEUTRAL_TEAM:
		return {"direction": unit.wander_direction, "intent": &"wander"}
	var nearest_chase_direction := Vector2.ZERO
	var nearest_threat_direction := Vector2.ZERO
	var detection_radius_squared: float = detection_radius * detection_radius
	var nearest_chase_distance_squared: float = detection_radius_squared
	var nearest_threat_distance_squared: float = detection_radius_squared
	var unit_position: Vector2 = positions_by_id.get(unit.unit_id, unit.position)
	for other_unit: PlanBUnit in units:
		if other_unit == unit:
			continue
		var other_position: Vector2 = positions_by_id.get(other_unit.unit_id, other_unit.position)
		var offset: Vector2 = other_position - unit_position
		var distance_squared: float = offset.length_squared()
		if distance_squared <= 0.000001 or distance_squared > detection_radius_squared:
			continue
		if other_unit.team == NEUTRAL_TEAM:
			if distance_squared < nearest_chase_distance_squared:
				nearest_chase_distance_squared = distance_squared
				nearest_chase_direction = offset.normalized()
		elif other_unit.team != unit.team:
			if _counters(other_unit, unit) and distance_squared < nearest_threat_distance_squared:
				nearest_threat_distance_squared = distance_squared
				nearest_threat_direction = -offset.normalized()
			elif _counters(unit, other_unit) and distance_squared < nearest_chase_distance_squared:
				nearest_chase_distance_squared = distance_squared
				nearest_chase_direction = offset.normalized()

	if nearest_threat_direction != Vector2.ZERO:
		var flee_direction: Vector2 = nearest_threat_direction * flee_weight + unit.wander_direction * wandering_weight
		return {"direction": flee_direction.normalized(), "intent": &"flee"}
	if nearest_chase_direction != Vector2.ZERO:
		var chase_direction: Vector2 = nearest_chase_direction * chase_weight + unit.wander_direction * wandering_weight
		return {"direction": chase_direction.normalized(), "intent": &"chase"}
	return {"direction": unit.wander_direction, "intent": &"wander"}


## 以棋子碰撞半径约束场景边缘，速度法线分量反射回战场。
func _bounce_from_play_area(unit: PlanBUnit) -> void:
	var minimum_x: float = play_area.position.x + unit_collision_radius
	var maximum_x: float = play_area.end.x - unit_collision_radius
	var minimum_y: float = play_area.position.y + unit_collision_radius
	var maximum_y: float = play_area.end.y - unit_collision_radius
	if unit.position.x < minimum_x:
		unit.position.x = minimum_x
		unit.velocity.x = absf(unit.velocity.x)
		unit.wander_direction.x = absf(unit.wander_direction.x)
	elif unit.position.x > maximum_x:
		unit.position.x = maximum_x
		unit.velocity.x = -absf(unit.velocity.x)
		unit.wander_direction.x = -absf(unit.wander_direction.x)
	if unit.position.y < minimum_y:
		unit.position.y = minimum_y
		unit.velocity.y = absf(unit.velocity.y)
		unit.wander_direction.y = absf(unit.wander_direction.y)
	elif unit.position.y > maximum_y:
		unit.position.y = maximum_y
		unit.velocity.y = -absf(unit.velocity.y)
		unit.wander_direction.y = -absf(unit.wander_direction.y)


## 棋子只会因真实寿命到期离场；替补总以新中立 ID 入场，不重置既有阵营。
func _despawn_expired_units() -> void:
	var expired_ids: Array[int] = []
	for unit_id: int in _get_sorted_unit_ids():
		var unit := _units_by_id.get(unit_id) as PlanBUnit
		if unit != null and unit.age_seconds >= unit.lifespan_seconds:
			expired_ids.append(unit_id)
	for unit_id: int in expired_ids:
		var unit := _units_by_id.get(unit_id) as PlanBUnit
		_units_by_id.erase(unit_id)
		if is_instance_valid(unit):
			remove_child(unit)
			unit.queue_free()
		unit_despawned.emit(unit_id)


## 空出总人口名额后按共享试算间隔逐个补充中立路人，满员时不积累补人欠账。
func _update_neutral_replenishment(delta: float) -> void:
	if _units_by_id.size() >= maximum_population:
		_spawn_elapsed_seconds = 0.0
		return
	_spawn_elapsed_seconds += delta
	if _spawn_elapsed_seconds < neutral_spawn_interval_seconds:
		return
	_spawn_elapsed_seconds = 0.0
	_spawn_unit(NEUTRAL_TEAM, {}, 0, _random_spawn_position())


## 初始化独立 Area2D 和运行快照后入场；同一场地的碰撞形状资源互不共享。
func _spawn_unit(team_value: StringName, word_definition: Dictionary, new_word_order: int, spawn_position: Vector2) -> PlanBUnit:
	var unit := UNIT_SCENE.instantiate() as PlanBUnit
	if unit == null:
		return null
	var wander := Vector2.from_angle(_rng.randf_range(0.0, TAU))
	var lifetime: float = _rng.randf_range(minf(lifespan_min_seconds, lifespan_max_seconds), maxf(lifespan_min_seconds, lifespan_max_seconds))
	var base_speed: float = _rng.randf_range(minf(base_speed_min, base_speed_max), maxf(base_speed_min, base_speed_max))
	unit.position = spawn_position
	add_child(unit)
	unit.configure_unit(
		_next_unit_id,
		team_value,
		word_definition,
		new_word_order,
		spawn_position,
		wander * base_speed,
		base_speed,
		lifetime,
		wander,
		_rng.randf_range(1.2, 3.1),
		unit_collision_radius
	)
	unit.collision_layer = 1
	unit.collision_mask = 1
	unit.monitoring = true
	unit.monitorable = true
	unit.area_entered.connect(_on_unit_area_entered.bind(_next_unit_id))
	_units_by_id[_next_unit_id] = unit
	_next_unit_id += 1
	unit_spawned.emit(unit.unit_id)
	return unit


## 按模拟区域的当前本地坐标取样，并为棋子半径留出边界内缩。
func _random_spawn_position() -> Vector2:
	var left: float = play_area.position.x + unit_collision_radius
	var right: float = play_area.end.x - unit_collision_radius
	var top: float = play_area.position.y + unit_collision_radius
	var bottom: float = play_area.end.y - unit_collision_radius
	if right < left or bottom < top:
		return play_area.get_center()
	return Vector2(_rng.randf_range(left, right), _rng.randf_range(top, bottom))


## 让分裂子体从目标周围展开；每个方向按请求次序稳定计算，且限制在实际战场内。
func _get_split_child_position(target_unit: PlanBUnit, child_index: int, child_count: int) -> Vector2:
	var angle: float = TAU * float(child_index) / float(maxi(child_count, 1))
	var spawn_offset: Vector2 = Vector2.from_angle(angle) * unit_collision_radius * 2.6
	var minimum: Vector2 = play_area.position + Vector2.ONE * unit_collision_radius
	var maximum: Vector2 = play_area.end - Vector2.ONE * unit_collision_radius
	return (target_unit.position + spawn_offset).clamp(minimum, maximum)


## 校验 C 提供的最小静态字段并深拷贝，运行时不持有词库可变引用。
func _copy_valid_word_definition(definition: Dictionary) -> Dictionary:
	var word_id: String = str(definition.get("word_id", "")).strip_edges()
	var text: String = str(definition.get("text", "")).strip_edges()
	var battle_type: String = str(definition.get("battle_type", "")).strip_edges()
	var tendency: String = str(definition.get("tendency", "")).strip_edges()
	var traits_value: Variant = definition.get("traits", [])
	var strength: int = int(definition.get("strength", 0))
	if word_id.is_empty() or text.is_empty() or battle_type.is_empty() or tendency.is_empty():
		return {}
	if strength < 1 or strength > 3 or not (traits_value is Array):
		return {}
	var copy: Dictionary = definition.duplicate(true)
	copy["word_id"] = word_id
	copy["text"] = text
	copy["battle_type"] = battle_type
	copy["strength"] = strength
	copy["traits"] = traits_value.duplicate(true)
	copy["tendency"] = tendency
	return copy


## 只根据外部注入的属性表检查克制方向，不用 strength 改写合法性。
func _counters(source_unit: PlanBUnit, target_unit: PlanBUnit) -> bool:
	if not source_unit.has_word() or not target_unit.has_word():
		return false
	var source_type: StringName = source_unit.get_battle_type()
	var target_type: StringName = target_unit.get_battle_type()
	return _type_counter_by_type.get(source_type, &"") == target_type


## 当前只允许玩家和对手作为可播种阵营。
func _is_faction(team_value: StringName) -> bool:
	return team_value == PLAYER_TEAM or team_value == OPPONENT_TEAM


## C 当前发送字符串 ID，A/B 内部使用 int；拒绝空值和非数字字符串。
func _normalize_unit_id(unit_id_value: Variant) -> int:
	if unit_id_value is int:
		return int(unit_id_value)
	var unit_id_text: String = str(unit_id_value).strip_edges()
	return unit_id_text.to_int() if unit_id_text.is_valid_int() else -1


## 所有对外快照和接触裁决复用稳定 ID 顺序。
func _get_sorted_unit_ids() -> Array[int]:
	var unit_ids: Array[int] = []
	for key: Variant in _units_by_id.keys():
		unit_ids.append(int(key))
	unit_ids.sort()
	return unit_ids


## 将当前有效棋子按 unit_id 排序，供移动和帧更新稳定遍历。
func _get_sorted_units() -> Array[PlanBUnit]:
	var units: Array[PlanBUnit] = []
	for unit_id: int in _get_sorted_unit_ids():
		var unit := _units_by_id.get(unit_id) as PlanBUnit
		if unit != null:
			units.append(unit)
	return units
