extends Node

signal pk_changed(value: float)
signal tier_changed(current_tier: int)
signal battle_ended(result: Variant)
signal unit_changed(unit_id: String, reason: String)
signal unit_spawned(unit_id: String)
signal unit_despawned(unit_id: String)

var _simulation
var _definitions: Dictionary = {}
var _used_word_ids: Array[String] = ["pb04_demo_used", "pb04_demo_old"]
var _pk_value := 52.0
var _cooldown_remaining := 0.0
var _next_word_order := 4


func configure(simulation, definitions: Array) -> void:
	_simulation = simulation
	_simulation.connect("unit_changed", Callable(self, "_on_unit_changed"))
	_simulation.connect("unit_spawned", Callable(self, "_on_unit_spawned"))
	_simulation.connect("unit_despawned", Callable(self, "_on_unit_despawned"))
	for definition in definitions:
		if definition is Dictionary:
			_definitions[str(definition.get("word_id", ""))] = definition.duplicate(true)


func _process(delta: float) -> void:
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if not is_instance_valid(_simulation):
		return
	var counts: Dictionary = _simulation.call("get_faction_counts")
	var next_value := clampf(50.0 + float(int(counts.get("player", 0)) - int(counts.get("opponent", 0))) * 0.45, 0.0, 100.0)
	if not is_equal_approx(next_value, _pk_value):
		_pk_value = next_value
		pk_changed.emit(_pk_value)


func get_pk() -> float:
	return _pk_value


func get_faction_counts() -> Dictionary:
	return _simulation.call("get_faction_counts")


func get_unit_snapshots() -> Array:
	return _simulation.call("get_unit_snapshots")


func get_demo_tier() -> int:
	return 2


func get_published_word_ids() -> Array:
	return _used_word_ids.duplicate()


func get_display_cooldown() -> float:
	return _cooldown_remaining


func publish_word(team: String, word_id: String, neutral_unit_id: String) -> Dictionary:
	if team != "player":
		return {"ok": false, "reason": "wrong_team"}
	if _cooldown_remaining > 0.0:
		return {"ok": false, "reason": "cooldown_active"}
	if _used_word_ids.has(word_id):
		return {"ok": false, "reason": "word_used"}
	if not _definitions.has(word_id):
		return {"ok": false, "reason": "word_unavailable"}
	if not is_instance_valid(_simulation) or not bool(_simulation.call("seed_unit", neutral_unit_id, team, _definitions[word_id], _next_word_order)):
		return {"ok": false, "reason": "target_not_neutral"}
	_used_word_ids.append(word_id)
	_cooldown_remaining = 5.0
	var committed_order := _next_word_order
	_next_word_order += 1
	return {"ok": true, "reason": "published", "word_order": committed_order}


func _on_unit_changed(unit_id: String, reason: String) -> void:
	unit_changed.emit(unit_id, reason)


func _on_unit_spawned(unit_id: String) -> void:
	unit_spawned.emit(unit_id)


func _on_unit_despawned(unit_id: String) -> void:
	unit_despawned.emit(unit_id)
