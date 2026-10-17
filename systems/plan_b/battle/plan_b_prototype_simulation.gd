class_name PlanBPrototypeSimulation
extends Node2D

## PB-01 临时棋子模块：实现 PB-02 所需的最小入口，正式模拟交付后可无损替换。

signal unit_changed(unit_id: String, reason: StringName)
signal unit_spawned(unit_id: String)
signal unit_despawned(unit_id: String)

const TYPE_BEATS: Dictionary = {
	"type_a": "type_b",
	"type_b": "type_c",
	"type_c": "type_a",
}
const CONVERSION_CHANCE_BY_STRENGTH: Array[float] = [0.0, 0.2, 0.35, 0.5]
const UNIT_RADIUS: float = 9.0
const CONTACT_COOLDOWN_SECONDS: float = 0.7

@export var initial_neutral_count: int = 76
@export var initial_opponent_count: int = 2
@export var maximum_unit_count: int = 96
@export var neutral_spawn_interval_seconds: float = 0.75
@export var average_lifespan_seconds: float = 65.0
@export var random_seed: int = 20261017

var _units: Array[Dictionary] = []
var _arena_size: Vector2 = Vector2(1120.0, 560.0)
var _arena_origin: Vector2 = Vector2.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_unit_number: int = 1
var _spawn_elapsed: float = 0.0
var _is_active: bool = false


func start_battle(arena_size: Vector2, arena_origin: Vector2 = Vector2.ZERO) -> void:
	# 每次开场或重开都重置棋子、人口时钟和随机种子，方便重复演示。
	for unit: Dictionary in _units:
		unit_despawned.emit(String(unit["unit_id"]))
	_units.clear()
	_next_unit_number = 1
	_spawn_elapsed = 0.0
	_arena_size = Vector2(maxf(arena_size.x, 100.0), maxf(arena_size.y, 100.0))
	_arena_origin = arena_origin
	_rng.seed = random_seed
	for _index: int in range(maxi(initial_neutral_count, 0)):
		_spawn_unit("neutral")
	for _index: int in range(maxi(initial_opponent_count, 0)):
		_spawn_unit("opponent")
	_is_active = true
	set_physics_process(true)


func set_active(active: bool) -> void:
	# 暂停只冻结棋子模拟；战斗编排器继续接收 UI 输入和发言请求。
	_is_active = active


func clear_battle() -> void:
	# 显式清除棋子并通知观察者，不依赖节点离树时的副作用。
	_is_active = false
	set_physics_process(false)
	for unit: Dictionary in _units:
		unit_despawned.emit(String(unit["unit_id"]))
	_units.clear()


func seed_unit(
	neutral_unit_id: Variant, team_value: StringName, word_definition: Dictionary, word_order: int
) -> bool:
	# 只把仍属中立的现有观众变为信徒；失败时不修改棋子或话语。
	var team: String = str(team_value)
	if not _is_active or (team != "player" and team != "opponent"):
		return false
	var target: Dictionary = _find_unit(str(neutral_unit_id))
	if target.is_empty() or String(target["team"]) != "neutral":
		return false
	if word_definition.is_empty() or word_order < 1:
		return false
	_apply_word_snapshot(target, team, word_definition, word_order)
	unit_changed.emit(neutral_unit_id, &"seed")
	return true


func get_faction_counts() -> Dictionary:
	# 人数始终从棋子运行态派生，不保存第二份可修改计数。
	var counts: Dictionary = {"player": 0, "opponent": 0, "neutral": 0}
	for unit: Dictionary in _units:
		var team: String = String(unit["team"])
		counts[team] = int(counts[team]) + 1
	return counts


func get_unit_snapshots() -> Array[Dictionary]:
	# UI 只拿深拷贝快照；不暴露棋子内部 Dictionary。
	var snapshots: Array[Dictionary] = []
	for unit: Dictionary in _units:
		snapshots.append(_snapshot_unit(unit))
	return snapshots


func get_unit_snapshot(unit_id: Variant) -> Dictionary:
	var unit: Dictionary = _find_unit(str(unit_id))
	return {} if unit.is_empty() else _snapshot_unit(unit)


func get_neutral_unit_ids() -> Array[String]:
	var neutral_ids: Array[String] = []
	for unit: Dictionary in _units:
		if String(unit["team"]) == "neutral":
			neutral_ids.append(String(unit["unit_id"]))
	return neutral_ids


func get_neutral_unit_at(position: Vector2, hit_radius: float = 18.0) -> String:
	# 点击命中最近的中立观众，给玩家提供稳定的中立目标 ID。
	var best_id: String = ""
	var best_distance_squared: float = hit_radius * hit_radius
	for unit: Dictionary in _units:
		if String(unit["team"]) != "neutral":
			continue
		var unit_position: Vector2 = unit["position"]
		var distance_squared: float = unit_position.distance_squared_to(position)
		if distance_squared <= best_distance_squared:
			best_distance_squared = distance_squared
			best_id = String(unit["unit_id"])
	return best_id


func _physics_process(delta: float) -> void:
	if not _is_active:
		return
	_update_units(delta)
	_update_contacts()
	_update_population(delta)


func _spawn_unit(team: String) -> void:
	var unit_id: String = "viewer_%03d" % _next_unit_number
	_next_unit_number += 1
	var margin: float = UNIT_RADIUS + 4.0
	var position: Vector2 = Vector2(
		_arena_origin.x + _rng.randf_range(margin, maxf(margin, _arena_size.x - margin)),
		_arena_origin.y + _rng.randf_range(margin, maxf(margin, _arena_size.y - margin))
	)
	var direction_angle: float = _rng.randf_range(0.0, TAU)
	var speed: float = _rng.randf_range(34.0, 76.0)
	var unit: Dictionary = {
		"unit_id": unit_id,
		"team": team,
		"word_id": "",
		"word_order": 0,
		"word_definition": {},
		"position": position,
		"velocity": Vector2(cos(direction_angle), sin(direction_angle)) * speed,
		"age": 0.0,
		"lifespan": _rng.randf_range(
			maxf(average_lifespan_seconds - 12.0, 1.0), average_lifespan_seconds + 12.0
		),
		"turn_time": _rng.randf_range(1.0, 3.0),
		"contact_cooldown": 0.0,
	}
	_units.append(unit)
	unit_spawned.emit(unit_id)


func _update_units(delta: float) -> void:
	for unit: Dictionary in _units:
		unit["age"] = float(unit["age"]) + delta
		unit["contact_cooldown"] = maxf(float(unit["contact_cooldown"]) - delta, 0.0)
		unit["turn_time"] = float(unit["turn_time"]) - delta
		if float(unit["turn_time"]) <= 0.0:
			var direction_angle: float = _rng.randf_range(0.0, TAU)
			var speed: float = _rng.randf_range(34.0, 76.0)
			unit["velocity"] = Vector2(cos(direction_angle), sin(direction_angle)) * speed
			unit["turn_time"] = _rng.randf_range(1.0, 3.0)
		var position: Vector2 = unit["position"] + unit["velocity"] * delta
		var velocity: Vector2 = unit["velocity"]
		if position.x < _arena_origin.x + UNIT_RADIUS or position.x > _arena_origin.x + _arena_size.x - UNIT_RADIUS:
			velocity.x = -velocity.x
			position.x = clampf(position.x, _arena_origin.x + UNIT_RADIUS, _arena_origin.x + _arena_size.x - UNIT_RADIUS)
		if position.y < _arena_origin.y + UNIT_RADIUS or position.y > _arena_origin.y + _arena_size.y - UNIT_RADIUS:
			velocity.y = -velocity.y
			position.y = clampf(position.y, _arena_origin.y + UNIT_RADIUS, _arena_origin.y + _arena_size.y - UNIT_RADIUS)
		unit["position"] = position
		unit["velocity"] = velocity


func _update_population(delta: float) -> void:
	# 有空位时持续补入中立观众；不为补人口改写已有阵营。
	_spawn_elapsed += delta
	if neutral_spawn_interval_seconds > 0.0 and _spawn_elapsed >= neutral_spawn_interval_seconds:
		_spawn_elapsed = fmod(_spawn_elapsed, neutral_spawn_interval_seconds)
		if _units.size() < maximum_unit_count:
			_spawn_unit("neutral")
	for index: int in range(_units.size() - 1, -1, -1):
		var unit: Dictionary = _units[index]
		if float(unit["age"]) < float(unit["lifespan"]):
			continue
		var unit_id: String = String(unit["unit_id"])
		_units.remove_at(index)
		unit_despawned.emit(unit_id)


func _update_contacts() -> void:
	# 原型使用小规模 O(n²) 接触扫描，最多96个棋子，保持实现直接可复现。
	var unit_count: int = _units.size()
	for first_index: int in range(unit_count):
		var first_unit: Dictionary = _units[first_index]
		if float(first_unit["contact_cooldown"]) > 0.0:
			continue
		for second_index: int in range(first_index + 1, unit_count):
			var second_unit: Dictionary = _units[second_index]
			if float(second_unit["contact_cooldown"]) > 0.0:
				continue
			var separation: Vector2 = second_unit["position"] - first_unit["position"]
			if separation.length_squared() > UNIT_RADIUS * UNIT_RADIUS * 4.0:
				continue
			_resolve_contact(first_unit, second_unit, separation)
			break


func _resolve_contact(first_unit: Dictionary, second_unit: Dictionary, separation: Vector2) -> void:
	# 每次合法接触只裁决一次，然后统一弹开并进入接触冷却。
	first_unit["contact_cooldown"] = CONTACT_COOLDOWN_SECONDS
	second_unit["contact_cooldown"] = CONTACT_COOLDOWN_SECONDS
	var normal: Vector2 = Vector2.RIGHT if separation.length_squared() < 0.001 else separation.normalized()
	var overlap: float = maxf(UNIT_RADIUS * 2.0 - separation.length(), 0.0)
	first_unit["position"] = first_unit["position"] - normal * overlap * 0.5
	second_unit["position"] = second_unit["position"] + normal * overlap * 0.5
	first_unit["velocity"] = first_unit["velocity"] - 2.0 * first_unit["velocity"].dot(normal) * normal
	second_unit["velocity"] = second_unit["velocity"] - 2.0 * second_unit["velocity"].dot(normal) * normal
	var first_team: String = String(first_unit["team"])
	var second_team: String = String(second_unit["team"])
	if first_team == second_team:
		_relay_new_word(first_unit, second_unit)
		return
	if first_team == "neutral":
		_try_convert(second_unit, first_unit)
		return
	if second_team == "neutral":
		_try_convert(first_unit, second_unit)
		return
	_resolve_faction_contact(first_unit, second_unit)


func _resolve_faction_contact(first_unit: Dictionary, second_unit: Dictionary) -> void:
	var first_word: Dictionary = first_unit["word_definition"]
	var second_word: Dictionary = second_unit["word_definition"]
	if first_word.is_empty() or second_word.is_empty():
		return
	var first_type: String = String(first_word.get("battle_type", ""))
	var second_type: String = String(second_word.get("battle_type", ""))
	if first_type == second_type:
		return
	if String(TYPE_BEATS.get(first_type, "")) == second_type:
		_try_convert(first_unit, second_unit)
	elif String(TYPE_BEATS.get(second_type, "")) == first_type:
		_try_convert(second_unit, first_unit)


func _try_convert(winner: Dictionary, loser: Dictionary) -> bool:
	var winner_word: Dictionary = winner["word_definition"]
	if winner_word.is_empty():
		return false
	var strength: int = clampi(int(winner_word.get("strength", 1)), 1, 3)
	if _rng.randf() >= CONVERSION_CHANCE_BY_STRENGTH[strength]:
		return false
	_apply_word_snapshot(
		loser, String(winner["team"]), winner_word, int(winner["word_order"])
	)
	unit_changed.emit(String(loser["unit_id"]), &"convert")
	return true


func _relay_new_word(first_unit: Dictionary, second_unit: Dictionary) -> void:
	# 同阵营按唯一 word_order 传话；相同顺序或空话不改变任何单位。
	var first_order: int = int(first_unit["word_order"])
	var second_order: int = int(second_unit["word_order"])
	if first_order > second_order and first_order > 0:
		_apply_word_snapshot(
			second_unit, String(second_unit["team"]), first_unit["word_definition"], first_order
		)
		unit_changed.emit(String(second_unit["unit_id"]), &"relay")
	elif second_order > first_order and second_order > 0:
		_apply_word_snapshot(
			first_unit, String(first_unit["team"]), second_unit["word_definition"], second_order
		)
		unit_changed.emit(String(first_unit["unit_id"]), &"relay")


func _apply_word_snapshot(
	unit: Dictionary, team: String, word_definition: Dictionary, word_order: int
) -> void:
	unit["team"] = team
	unit["word_id"] = String(word_definition.get("word_id", ""))
	unit["word_order"] = word_order
	unit["word_definition"] = word_definition.duplicate(true)


func _find_unit(unit_id: String) -> Dictionary:
	for unit: Dictionary in _units:
		if String(unit["unit_id"]) == unit_id:
			return unit
	return {}


func _snapshot_unit(unit: Dictionary) -> Dictionary:
	var definition: Dictionary = unit["word_definition"].duplicate(true)
	return {
		"unit_id": unit["unit_id"],
		"team": unit["team"],
		"word_id": unit["word_id"],
		"word_order": unit["word_order"],
		"text": String(definition.get("text", "")),
		"battle_type": String(definition.get("battle_type", "")),
		"strength": int(definition.get("strength", 0)),
		"traits": definition.get("traits", []).duplicate(true),
		"position": unit["position"],
		"velocity": unit["velocity"],
		"age": unit["age"],
		"word_definition": definition,
	}
