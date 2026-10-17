## 一名观众棋子的物理区域和唯一运行状态。
class_name PlanBUnit
extends Area2D

var unit_id: int = -1
var team: StringName = &"neutral"
var word_order: int = 0
var velocity: Vector2 = Vector2.ZERO
var base_speed: float = 0.0
var age_seconds: float = 0.0
var lifespan_seconds: float = 65.0
var contact_cooldown_remaining: float = 0.0
var wander_direction: Vector2 = Vector2.RIGHT
var wander_change_remaining: float = 0.0
var motion_intent: StringName = &"wander"

var _word_definition: Dictionary = {}
var _collision_radius: float = 13.0


## 初始化单个棋子的运行事实；话语字典在入场时深拷贝，避免反向改写 C 的静态配置。
func configure_unit(
	new_unit_id: int,
	new_team: StringName,
	definition: Dictionary,
	new_word_order: int,
	new_position: Vector2,
	new_velocity: Vector2,
	new_base_speed: float,
	new_lifespan_seconds: float,
	new_wander_direction: Vector2,
	new_wander_change_remaining: float,
	collision_radius: float
) -> void:
	unit_id = new_unit_id
	team = new_team
	_word_definition = definition.duplicate(true)
	word_order = new_word_order
	position = new_position
	velocity = new_velocity
	base_speed = new_base_speed
	lifespan_seconds = new_lifespan_seconds
	wander_direction = new_wander_direction.normalized()
	wander_change_remaining = new_wander_change_remaining
	_collision_radius = maxf(collision_radius, 1.0)
	_set_collision_radius(collision_radius)


## 整体替换当前传播快照；中立棋子会在 seed 时第一次获得话语。
func apply_word_snapshot(new_team: StringName, definition: Dictionary, new_word_order: int) -> void:
	team = new_team
	_word_definition = definition.duplicate(true)
	word_order = new_word_order


func has_word() -> bool:
	return not _word_definition.is_empty()


func get_word_snapshot() -> Dictionary:
	return _word_definition.duplicate(true)


func get_battle_type() -> StringName:
	return StringName(str(_word_definition.get("battle_type", "")))


func get_strength() -> int:
	return int(_word_definition.get("strength", 0))


## 给 PB-04 返回可以自由读取的深拷贝，不暴露节点内部词语状态。
func get_public_snapshot() -> Dictionary:
	var snapshot: Dictionary = _word_definition.duplicate(true)
	snapshot["unit_id"] = unit_id
	snapshot["team"] = str(team)
	snapshot["word_order"] = word_order
	snapshot["word_id"] = str(_word_definition.get("word_id", ""))
	snapshot["text"] = str(_word_definition.get("text", ""))
	snapshot["battle_type"] = str(_word_definition.get("battle_type", ""))
	snapshot["strength"] = get_strength()
	snapshot["traits"] = _word_definition.get("traits", []).duplicate(true)
	snapshot["tendency"] = str(_word_definition.get("tendency", ""))
	snapshot["position"] = global_position
	snapshot["velocity"] = velocity
	snapshot["age"] = age_seconds
	snapshot["lifespan"] = lifespan_seconds
	snapshot["collision_cooldown"] = contact_cooldown_remaining
	snapshot["motion_intent"] = str(motion_intent)
	return snapshot


## 每个棋子使用独立圆形 Shape，防止实例共用 Resource 时互相改半径。
func _set_collision_radius(radius: float) -> void:
	var collision_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_node == null or not (collision_node.shape is CircleShape2D):
		return
	var instance_shape := collision_node.shape.duplicate() as CircleShape2D
	instance_shape.radius = maxf(radius, 1.0)
	collision_node.shape = instance_shape
	_collision_radius = instance_shape.radius
