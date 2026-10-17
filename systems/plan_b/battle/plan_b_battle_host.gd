class_name PlanBBattleHost
extends Node

## Plan B 普通战斗的编排与 PK 唯一所有者；不接入正式 Sandbox 的命中或回拉系统。

signal pk_changed(value: float)
signal tier_changed(current_tier: int)
signal battle_ended(result: StringName)
signal battle_state_changed(state: StringName)
signal publish_result(team: String, word_id: String, result: Dictionary)
signal unit_changed(unit_id: String, reason: String)
signal unit_spawned(unit_id: String)
signal unit_despawned(unit_id: String)

const TIER_CATALOG: Resource = preload("res://data/combat_stage/tier_catalog.tres")
const PROTOTYPE_CATALOG_SCRIPT: Script = preload("res://systems/plan_b/battle/plan_b_prototype_word_library.gd")
const PROTOTYPE_OPPONENT_SCRIPT: Script = preload("res://systems/plan_b/battle/plan_b_prototype_opponent_director.gd")

@export_range(0.0, 5.0, 0.01) var pk_rate_pp_per_second: float = 0.85
@export_range(0.0, 60.0, 0.1) var player_publish_cooldown_seconds: float = 5.0
@export_range(0.0, 60.0, 0.1) var opponent_publish_cooldown_seconds: float = 11.5
@export var available_level: String = "level_001"
@export var opponent_auto_publish_enabled: bool = true

enum BattleState { IDLE, RUNNING, PAUSED, ENDED }

var _simulation: Node
var _word_catalog: Object
var _opponent_director: Object
var _battle_state: int = BattleState.IDLE
var _battle_elapsed: float = 0.0
var _pk: float = 0.5
var _current_tier: int = 0
var _next_word_order: int = 1
var _used_word_ids: Array[String] = []
var _last_published_at: Dictionary = {"player": -1000000.0, "opponent": -1000000.0}
var _simulation_uses_integer_unit_ids: bool = false


func _ready() -> void:
	# 临时占位模块也走公开对象接口，正式 B/C 模块可由场景根注入替换。
	_simulation = get_node_or_null("Simulation")
	_word_catalog = PROTOTYPE_CATALOG_SCRIPT.new()
	_opponent_director = PROTOTYPE_OPPONENT_SCRIPT.new()
	_bind_simulation_signals()
	_bind_opponent_signal()
	_load_word_catalog()
	_configure_simulation_type_matchups()
	_configure_opponent_director()


func configure_modules(simulation: Node, word_catalog: Object, opponent_director: Object) -> bool:
	# A 的组装根可注入 B/C 模块；运行中的战斗不允许改换状态拥有者。
	if _battle_state == BattleState.RUNNING or _battle_state == BattleState.PAUSED:
		return false
	if simulation != null and simulation != _simulation:
		_disconnect_simulation_signals()
		_simulation = simulation
		_bind_simulation_signals()
	if word_catalog != null:
		_word_catalog = word_catalog
		if not _load_word_catalog():
			return false
	if opponent_director != null:
		_disconnect_opponent_signal()
		_opponent_director = opponent_director
		_bind_opponent_signal()
	_configure_simulation_type_matchups()
	return _configure_opponent_director()


func start_battle(arena_size: Vector2, arena_origin: Vector2 = Vector2.ZERO) -> void:
	# 新开和重开统一重置顺序、冷却、PK、Tier 与棋子人口。
	if _simulation == null:
		push_error("PlanBBattleHost 缺少 Simulation 模块。")
		return
	_battle_state = BattleState.RUNNING
	_battle_elapsed = 0.0
	_pk = 0.5
	_current_tier = 0
	_next_word_order = 1
	_used_word_ids.clear()
	_last_published_at = {"player": -1000000.0, "opponent": -1000000.0}
	_configure_simulation_type_matchups()
	_configure_opponent_director()
	_start_simulation(arena_size, arena_origin)
	_update_simulation_unit_id_kind()
	battle_state_changed.emit(&"running")
	pk_changed.emit(get_pk())
	tier_changed.emit(_current_tier)


func pause_battle() -> void:
	if _battle_state != BattleState.RUNNING:
		return
	_battle_state = BattleState.PAUSED
	_simulation.call("set_active", false)
	battle_state_changed.emit(&"paused")


func resume_battle() -> void:
	if _battle_state != BattleState.PAUSED:
		return
	_battle_state = BattleState.RUNNING
	_simulation.call("set_active", true)
	battle_state_changed.emit(&"running")


func restart_battle(arena_size: Vector2, arena_origin: Vector2 = Vector2.ZERO) -> void:
	start_battle(arena_size, arena_origin)


func end_battle(result: StringName) -> void:
	# 结束状态只提交一次，0% 与100%分别由 PK 采样交出事实。
	if _battle_state == BattleState.ENDED:
		return
	_battle_state = BattleState.ENDED
	_simulation.call("set_active", false)
	battle_state_changed.emit(&"ended")
	battle_ended.emit(result)


func get_pk() -> float:
	# 公共值使用0到100的百分点，和PB-04 HUD一致；阈值计算继续使用内部比例。
	return _pk * 100.0


func get_faction_counts() -> Dictionary:
	# 转发模拟模块的只读事实，PK 和 HUD 都从同一棋子计数采样。
	return {} if _simulation == null else _simulation.call("get_faction_counts")


func get_unit_snapshots() -> Array[Dictionary]:
	return [] if _simulation == null else _simulation.call("get_unit_snapshots")


func get_neutral_unit_at(scene_position: Vector2) -> Variant:
	# B 以实际场景坐标命中；无目标时统一转换为空 ID 供输入层提示。
	if _simulation == null:
		return ""
	var unit_id: Variant = _simulation.call("get_neutral_unit_at", scene_position)
	if unit_id is int and int(unit_id) < 0:
		return ""
	return unit_id


func get_current_tier() -> int:
	return _current_tier


func get_battle_state() -> StringName:
	match _battle_state:
		BattleState.RUNNING:
			return &"running"
		BattleState.PAUSED:
			return &"paused"
		BattleState.ENDED:
			return &"ended"
		_:
			return &"idle"


func get_used_word_ids() -> Array[String]:
	return _used_word_ids.duplicate()


func get_available_word_ids(team: String) -> Array[String]:
	if _word_catalog == null or not _word_catalog.has_method("get_available_word_ids"):
		return []
	return _word_catalog.call("get_available_word_ids", team, _used_word_ids, available_level)


func get_word_definitions(team: String) -> Array[Dictionary]:
	# 给 PB-04 一次性读取当前关卡词条；去重状态仍只由 A 保存。
	var word_ids: Array[String] = []
	if _word_catalog == null:
		return []
	if _word_catalog.has_method("get_word_ids"):
		word_ids = _word_catalog.call("get_word_ids", available_level, team)
	else:
		word_ids = _word_catalog.call("get_available_word_ids", team, [], available_level)
	var definitions: Array[Dictionary] = []
	for word_id: String in word_ids:
		var definition: Dictionary = get_word_definition(word_id)
		if not definition.is_empty():
			definitions.append(definition)
	return definitions


func get_word_definition(word_id: String) -> Dictionary:
	if _word_catalog == null or not _word_catalog.has_method("get_word_definition"):
		return {}
	return _word_catalog.call("get_word_definition", word_id)


func get_publish_cooldown_remaining(team: String) -> float:
	if team != "player" and team != "opponent":
		return 0.0
	var cooldown: float = player_publish_cooldown_seconds if team == "player" else opponent_publish_cooldown_seconds
	var elapsed_since_publish: float = _battle_elapsed - float(_last_published_at.get(team, -1000000.0))
	return maxf(cooldown - elapsed_since_publish, 0.0)


func publish_word(team: String, word_id: String, neutral_unit_id: Variant) -> Dictionary:
	# 只有 B 成功播种后才提交 A 拥有的已用词、阵营冷却和全局顺序号。
	var failure: Dictionary = {"ok": false, "reason": &"invalid_request"}
	if _battle_state != BattleState.RUNNING:
		failure["reason"] = &"battle_not_running"
		return _report_publish_result(team, word_id, failure)
	if team != "player" and team != "opponent":
		failure["reason"] = &"invalid_team"
		return _report_publish_result(team, word_id, failure)
	var definition: Dictionary = get_word_definition(word_id)
	if definition.is_empty():
		failure["reason"] = &"unknown_word"
		return _report_publish_result(team, word_id, failure)
	if _used_word_ids.has(word_id):
		failure["reason"] = &"word_already_used"
		return _report_publish_result(team, word_id, failure)
	var cooldown_remaining: float = get_publish_cooldown_remaining(team)
	if cooldown_remaining > 0.0:
		failure["reason"] = &"cooldown"
		failure["cooldown_remaining"] = cooldown_remaining
		return _report_publish_result(team, word_id, failure)
	var target_id: Variant = _normalize_unit_id(neutral_unit_id)
	var target: Dictionary = _simulation.call("get_unit_snapshot", target_id)
	if target.is_empty() or String(target.get("team", "")) != "neutral":
		failure["reason"] = &"invalid_target"
		return _report_publish_result(team, word_id, failure)
	var candidate_order: int = _next_word_order
	if not bool(_simulation.call("seed_unit", target_id, StringName(team), definition, candidate_order)):
		failure["reason"] = &"seed_failed"
		return _report_publish_result(team, word_id, failure)
	_used_word_ids.append(word_id)
	_last_published_at[team] = _battle_elapsed
	_next_word_order += 1
	var success: Dictionary = {"ok": true, "reason": &"published", "word_order": candidate_order}
	return _report_publish_result(team, word_id, success)


func update_pk(delta: float) -> void:
	# PK 只按模拟模块真实棋子人数和经过时间变化；相等人数时变化量为零。
	if _battle_state != BattleState.RUNNING or delta <= 0.0:
		return
	var counts: Dictionary = _simulation.call("get_faction_counts")
	var total_count: int = int(counts.get("player", 0)) + int(counts.get("opponent", 0)) + int(counts.get("neutral", 0))
	if total_count <= 0:
		return
	var player_difference: float = float(int(counts.get("player", 0)) - int(counts.get("opponent", 0)))
	var change_ratio: float = pk_rate_pp_per_second * player_difference / float(total_count) * delta / 100.0
	var updated_pk: float = clampf(_pk + change_ratio, 0.0, 1.0)
	if not is_equal_approx(updated_pk, _pk):
		_pk = updated_pk
		_update_tier()
		pk_changed.emit(get_pk())
	if _pk <= 0.0:
		end_battle(&"failed")
	elif _pk >= 1.0:
		end_battle(&"enter_contradiction")


func update_battle(delta: float) -> void:
	# C 每帧只决定候选；发表、顺序号和 PK 真相继续由 A 提交与结算。
	if _battle_state != BattleState.RUNNING or delta <= 0.0:
		return
	_battle_elapsed += delta
	if opponent_auto_publish_enabled:
		_update_opponent_speech(delta)
	update_pk(delta)


func _process(delta: float) -> void:
	update_battle(delta)


func _update_tier() -> void:
	# 阈值取现有 Tier Catalog（由08表导入），只提供临时展示，不触发正式阶段演出。
	var tier: int = _current_tier
	while tier < 5:
		var current_config: Resource = TIER_CATALOG.call("get_tier_config", tier)
		if current_config == null or _pk < float(current_config.get("upgrade_threshold")):
			break
		tier += 1
	while tier > 0:
		var tier_config: Resource = TIER_CATALOG.call("get_tier_config", tier)
		if tier_config == null or _pk >= float(tier_config.get("downgrade_threshold")):
			break
		tier -= 1
	if tier == _current_tier:
		return
	_current_tier = tier
	tier_changed.emit(_current_tier)


func _start_simulation(arena_size: Vector2, arena_origin: Vector2) -> void:
	if _simulation.has_method("start_battle"):
		_simulation.call("start_battle", arena_size, arena_origin)
		return
	if _simulation.has_method("clear_battle"):
		_simulation.call("clear_battle")
	if _simulation.has_method("set_play_area"):
		_simulation.call("set_play_area", Rect2(arena_origin, arena_size))
	if _simulation.has_method("create_population"):
		_simulation.call("create_population")
	if _simulation.has_method("start_simulation"):
		_simulation.call("start_simulation")
	else:
		_simulation.call("set_active", true)


func _update_opponent_speech(delta: float) -> void:
	if _opponent_director == null or not _opponent_director.has_method("update_speech"):
		return
	var neutral_snapshots: Array[Dictionary] = []
	for snapshot: Dictionary in get_unit_snapshots():
		if String(snapshot.get("team", "")) == "neutral":
			neutral_snapshots.append(snapshot)
	_opponent_director.call(
		"update_speech", delta, neutral_snapshots, get_available_word_ids("opponent")
	)


func _load_word_catalog() -> bool:
	if _word_catalog != null and _word_catalog.has_method("load_test_configuration"):
		return bool(_word_catalog.call("load_test_configuration"))
	return _word_catalog != null


func _configure_opponent_director() -> bool:
	if _opponent_director == null:
		return false
	if _opponent_director.has_method("configure"):
		return bool(_opponent_director.call("configure", _word_catalog, 20261017))
	if _opponent_director.has_method("reset"):
		_opponent_director.call("reset")
	return true


func _configure_simulation_type_matchups() -> void:
	# 正式原型中 C 提供唯一属性关系表，A 注入 B；临时模拟器使用本地候选表。
	if _simulation == null or _word_catalog == null \
		or not _simulation.has_method("set_type_counter_map") \
		or not _word_catalog.has_method("get_type_matchup"):
		return
	var battle_types: Array[String] = []
	for team: String in ["player", "opponent"]:
		for definition: Dictionary in get_word_definitions(team):
			var battle_type: String = str(definition.get("battle_type", ""))
			if not battle_type.is_empty() and not battle_types.has(battle_type):
				battle_types.append(battle_type)
	var counter_map: Dictionary = {}
	for attacker_type: String in battle_types:
		for defender_type: String in battle_types:
			if attacker_type == defender_type:
				continue
			var relation: StringName = StringName(
				_word_catalog.call("get_type_matchup", attacker_type, defender_type)
			)
			if relation == &"advantage":
				counter_map[attacker_type] = defender_type
				break
	if not counter_map.is_empty():
		_simulation.call("set_type_counter_map", counter_map)


func _bind_simulation_signals() -> void:
	if _simulation == null:
		return
	_connect_signal(_simulation, &"unit_changed", Callable(self, "_on_unit_changed"))
	_connect_signal(_simulation, &"unit_spawned", Callable(self, "_on_unit_spawned"))
	_connect_signal(_simulation, &"unit_despawned", Callable(self, "_on_unit_despawned"))


func _disconnect_simulation_signals() -> void:
	if _simulation == null:
		return
	_disconnect_signal(_simulation, &"unit_changed", Callable(self, "_on_unit_changed"))
	_disconnect_signal(_simulation, &"unit_spawned", Callable(self, "_on_unit_spawned"))
	_disconnect_signal(_simulation, &"unit_despawned", Callable(self, "_on_unit_despawned"))


func _bind_opponent_signal() -> void:
	_connect_signal(_opponent_director, &"publish_word_requested", Callable(self, "_on_opponent_publish_requested"))


func _disconnect_opponent_signal() -> void:
	_disconnect_signal(
		_opponent_director, &"publish_word_requested", Callable(self, "_on_opponent_publish_requested")
	)


func _connect_signal(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source != null and source.has_signal(signal_name) and not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)


func _disconnect_signal(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source != null and source.has_signal(signal_name) and source.is_connected(signal_name, callback):
		source.disconnect(signal_name, callback)


func _normalize_unit_id(unit_id: Variant) -> Variant:
	if unit_id is int or not _simulation_uses_integer_unit_ids:
		return unit_id
	var unit_id_text: String = str(unit_id)
	return int(unit_id_text) if unit_id_text.is_valid_int() else -1


func _update_simulation_unit_id_kind() -> void:
	_simulation_uses_integer_unit_ids = false
	var snapshots: Array[Dictionary] = get_unit_snapshots()
	if not snapshots.is_empty():
		_simulation_uses_integer_unit_ids = snapshots[0].get("unit_id") is int


func _report_publish_result(team: String, word_id: String, result: Dictionary) -> Dictionary:
	publish_result.emit(team, word_id, result.duplicate(true))
	return result


func _on_opponent_publish_requested(word_id: String, neutral_unit_id: String) -> void:
	# C 的请求仍必须通过 A 统一校验和 B 播种。
	publish_word("opponent", word_id, neutral_unit_id)


func _on_unit_changed(unit_id: Variant, reason: StringName) -> void:
	unit_changed.emit(str(unit_id), str(reason))


func _on_unit_spawned(unit_id: Variant) -> void:
	unit_spawned.emit(str(unit_id))


func _on_unit_despawned(unit_id: Variant) -> void:
	unit_despawned.emit(str(unit_id))
