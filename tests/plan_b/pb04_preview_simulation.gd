extends Node

signal unit_changed(unit_id: String, reason: String)
signal unit_spawned(unit_id: String)
signal unit_despawned(unit_id: String)

const WORLD_BOUNDS := Rect2(Vector2.ZERO, Vector2(900.0, 490.0))

var _units: Array = []
var _elapsed := 0.0
var _spawn_sent := false
var _despawn_sent := false
var _convert_sent := false
var _relay_sent := false


func _ready() -> void:
	# 95 棋子的中途局夹具稍后补到上限 96，用于检查满场排布。
	_build_fixture()


func _process(delta: float) -> void:
	_elapsed += delta
	_move_units(delta)
	if not _spawn_sent and _elapsed > 0.8:
		_spawn_preview_audience()
	if not _convert_sent and _elapsed > 2.8:
		_preview_contact("convert")
	if not _relay_sent and _elapsed > 4.6:
		_preview_contact("relay")
	if not _despawn_sent and _elapsed > 8.0:
		_despawn_preview_audience()


func get_faction_counts() -> Dictionary:
	var result := {"player": 0, "opponent": 0, "neutral": 0}
	for unit in _units:
		var team := str(unit.get("team", "neutral"))
		result[team] = int(result.get(team, 0)) + 1
	return result


func get_unit_snapshots() -> Array:
	return _units.duplicate(true)


func seed_unit(neutral_unit_id: String, team: String, word_definition: Dictionary, word_order: int) -> bool:
	for index in range(_units.size()):
		var unit: Dictionary = _units[index]
		if str(unit.get("unit_id", "")) != neutral_unit_id or str(unit.get("team", "")) != "neutral":
			continue
		unit = unit.duplicate(true)
		unit["team"] = team
		unit["word_id"] = str(word_definition.get("word_id", ""))
		unit["word_order"] = word_order
		unit["battle_type"] = str(word_definition.get("battle_type", ""))
		unit["strength"] = int(word_definition.get("strength", 1))
		unit["traits"] = word_definition.get("traits", []).duplicate(true)
		unit["text"] = str(word_definition.get("text", ""))
		_units[index] = unit
		unit_changed.emit(neutral_unit_id, "seed")
		return true
	return false


func _build_fixture() -> void:
	for index in range(95):
		var team := "player" if index < 22 else ("opponent" if index < 42 else "neutral")
		var row := floori(float(index) / 12.0)
		var column := index % 12
		var position := Vector2(42.0 + float(column) * 73.0, 34.0 + float(row) * 60.0 + float(index % 3) * 4.0)
		var angle := float(index) * 2.39996323
		var speed := 10.0 + float(index % 7) * 1.3
		var word_id := ""
		var word_order := 0
		if team == "player":
			word_id = "pb04_demo_used" if index < 12 else "pb04_demo_old"
			word_order = 1 if index < 12 else 3
		elif team == "opponent":
			word_id = "pb04_demo_foe"
			word_order = 2
		_units.append({
			"unit_id": "AUD-%03d" % (index + 1),
			"team": team,
			"word_id": word_id,
			"word_order": word_order,
			"battle_type": "type_a" if team == "player" else ("type_b" if team == "opponent" else ""),
			"strength": 2 if team != "neutral" else 0,
			"traits": [],
			"position": position,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"text": "",
		})


func _move_units(delta: float) -> void:
	for index in range(_units.size()):
		var unit: Dictionary = _units[index]
		var position: Vector2 = unit.get("position", Vector2.ZERO)
		var velocity: Vector2 = unit.get("velocity", Vector2.ZERO)
		position += velocity * delta
		if position.x < 20.0 or position.x > WORLD_BOUNDS.size.x - 20.0:
			velocity.x *= -1.0
		if position.y < 20.0 or position.y > WORLD_BOUNDS.size.y - 20.0:
			velocity.y *= -1.0
		position.x = clampf(position.x, 20.0, WORLD_BOUNDS.size.x - 20.0)
		position.y = clampf(position.y, 20.0, WORLD_BOUNDS.size.y - 20.0)
		unit = unit.duplicate(true)
		unit["position"] = position
		unit["velocity"] = velocity
		_units[index] = unit


func _spawn_preview_audience() -> void:
	_spawn_sent = true
	_units.append({
		"unit_id": "AUD-096",
		"team": "neutral",
		"word_id": "",
		"word_order": 0,
		"battle_type": "",
		"strength": 0,
		"traits": [],
		"position": Vector2(840.0, 435.0),
		"velocity": Vector2(-11.0, -8.0),
		"text": "",
	})
	unit_spawned.emit("AUD-096")


func _preview_contact(reason: String) -> void:
	# 只在 UI 审核夹具中驱动两种接触结果，正式碰撞由 PB-02 拥有。
	if reason == "convert":
		for index in range(_units.size()):
			if str(_units[index].get("team", "")) == "neutral":
				var unit: Dictionary = _units[index].duplicate(true)
				unit["team"] = "player"
				unit["word_id"] = "pb04_demo_used"
				unit["word_order"] = 1
				unit["battle_type"] = "type_a"
				unit["strength"] = 2
				unit["text"] = ""
				_units[index] = unit
				unit_changed.emit(str(unit.get("unit_id", "")), "convert")
				return
	if reason == "relay":
		for index in range(_units.size()):
			if str(_units[index].get("team", "")) == "player" and str(_units[index].get("word_id", "")) == "pb04_demo_old":
				var unit: Dictionary = _units[index].duplicate(true)
				unit["word_id"] = "pb04_demo_used"
				unit["word_order"] = 1
				unit["text"] = ""
				_units[index] = unit
				unit_changed.emit(str(unit.get("unit_id", "")), "relay")
				return


func _despawn_preview_audience() -> void:
	_despawn_sent = true
	for index in range(_units.size() - 1, -1, -1):
		if str(_units[index].get("unit_id", "")) == "AUD-096":
			_units.remove_at(index)
			unit_despawned.emit("AUD-096")
			return
