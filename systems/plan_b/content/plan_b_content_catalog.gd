class_name PlanBContentCatalog
extends RefCounted

const WORD_POOL_PATH := "res://data/plan_b/word_pool.csv"
const TYPE_MATCHUPS_PATH := "res://data/plan_b/battle_type_matchups.csv"
const STRENGTH_RATES_PATH := "res://data/plan_b/strength_success_rates.csv"
const FERMI_CONFIG_PATH := "res://data/plan_b/fermi_opponent_config.csv"
const RETALIATION_MAP_PATH := "res://data/plan_b/retaliation_skill_map.csv"

const LEGACY_TENDENCIES := [&"orthodox", &"heresy", &"absurd", &"neutral"]

var _word_definitions: Dictionary = {}
var _word_ids_in_source_order: Array[String] = []
var _type_relations: Dictionary = {}
var _strength_probabilities: Dictionary = {}
var _opponent_configs: Dictionary = {}
var _retaliation_mappings: Array[Dictionary] = []
var _loaded: bool = false


## 从 Plan B 独立 TEST_ONLY 表读取词句与战斗参数，不改正式源表。
func load_test_configuration() -> bool:
	_loaded = false
	_word_definitions.clear()
	_word_ids_in_source_order.clear()
	_type_relations.clear()
	_strength_probabilities.clear()
	_opponent_configs.clear()
	_retaliation_mappings.clear()

	var raw_matchups: Array[Dictionary] = _read_csv_rows(TYPE_MATCHUPS_PATH)
	var raw_strengths: Array[Dictionary] = _read_csv_rows(STRENGTH_RATES_PATH)
	var raw_words: Array[Dictionary] = _read_csv_rows(WORD_POOL_PATH)
	var raw_opponents: Array[Dictionary] = _read_csv_rows(FERMI_CONFIG_PATH)
	var raw_retaliations: Array[Dictionary] = _read_csv_rows(RETALIATION_MAP_PATH)
	if raw_matchups.is_empty() or raw_strengths.is_empty() or raw_words.is_empty() \
		or raw_opponents.is_empty() or raw_retaliations.is_empty():
		return false

	for row: Dictionary in raw_matchups:
		var attacker: String = str(row.get("attacker_type", "")).strip_edges()
		var defender: String = str(row.get("defender_type", "")).strip_edges()
		var relation: String = str(row.get("relation", "")).strip_edges()
		if attacker.is_empty() or defender.is_empty() or relation not in ["same", "advantage", "disadvantage"]:
			return false
		var relation_key := _make_matchup_key(attacker, defender)
		if _type_relations.has(relation_key):
			return false
		_type_relations[relation_key] = StringName(relation)
	if not _has_complete_matchup_table():
		return false

	for row: Dictionary in raw_strengths:
		var strength_text: String = str(row.get("strength", "")).strip_edges()
		var chance_text: String = str(row.get("conversion_probability", "")).strip_edges()
		if not strength_text.is_valid_int() or not chance_text.is_valid_float():
			return false
		var strength: int = int(strength_text)
		var chance: float = float(chance_text)
		if strength < 1 or strength > 3 or chance < 0.0 or chance > 1.0 \
			or _strength_probabilities.has(strength):
			return false
		_strength_probabilities[strength] = chance
	if _strength_probabilities.size() != 3:
		return false

	for row: Dictionary in raw_words:
		if not _has_required_word_fields(row):
			return false
		var word_id: String = str(row.get("word_id", "")).strip_edges()
		var text: String = str(row.get("text", ""))
		var battle_type: String = str(row.get("battle_type", "")).strip_edges()
		var strength_text: String = str(row.get("strength", "")).strip_edges()
		var tendency := StringName(str(row.get("tendency", "")).strip_edges())
		var audience := StringName(str(row.get("available_to", "")).strip_edges())
		if word_id.is_empty() or text.is_empty() or _word_definitions.has(word_id) \
			or not strength_text.is_valid_int() or not LEGACY_TENDENCIES.has(tendency) \
			or audience not in [&"player", &"opponent"] \
			or not _type_relations.has(_make_matchup_key(battle_type, battle_type)) \
			or not _strength_probabilities.has(int(strength_text)) \
			or str(row.get("test_only", "")).to_lower() != "true":
			return false

		var definition := {
			"word_id": word_id,
			"text": text,
			"battle_type": StringName(battle_type),
			"strength": int(strength_text),
			"traits": _parse_trait_ids(str(row.get("traits", ""))),
			"tendency": tendency,
			"available_level": StringName(str(row.get("available_level", "")).strip_edges()),
			"available_to": audience,
			"source_table": str(row.get("source_table", "")),
			"source_id": str(row.get("source_id", "")),
			"test_only": true,
		}
		if String(definition["available_level"]).is_empty() \
			or str(definition["source_table"]).is_empty() or str(definition["source_id"]).is_empty():
			return false
		_word_definitions[word_id] = definition
		_word_ids_in_source_order.append(word_id)

	for row: Dictionary in raw_opponents:
		var opponent_id: String = str(row.get("opponent_id", "")).strip_edges()
		if opponent_id.is_empty() or _opponent_configs.has(opponent_id):
			return false
		var config := _parse_opponent_config(row)
		if config.is_empty():
			return false
		_opponent_configs[opponent_id] = config

	for row: Dictionary in raw_retaliations:
		_retaliation_mappings.append(_parse_retaliation_mapping(row))
	_loaded = not _word_definitions.is_empty() and _opponent_configs.has("fermi")
	return _loaded


## 返回词条值快照；嵌套 traits 也复制，运行单位无法改写词库缓存。
func get_word_definition(word_id: String) -> Dictionary:
	if not _loaded:
		return {}
	var definition: Dictionary = _word_definitions.get(word_id, {})
	return definition.duplicate(true)


## 按关卡与使用方返回可用 word_id；最终消耗状态归 PB-01。
func get_word_ids(available_level: String, audience: String) -> Array[String]:
	var result: Array[String] = []
	if not _loaded:
		return result
	for word_id: String in _word_ids_in_source_order:
		var definition: Dictionary = _word_definitions[word_id]
		if str(definition["available_level"]) == available_level \
			and str(definition["available_to"]) == audience:
			result.append(word_id)
	return result


## 给 UI / 对手决策读取完整只读列表，每项都与内部配置断开。
func get_word_definitions(available_level: String, audience: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for word_id: String in get_word_ids(available_level, audience):
		result.append(get_word_definition(word_id))
	return result


## 返回攻击方相对防守方的关系：advantage / disadvantage / same。
func get_type_matchup(attacker_type: String, defender_type: String) -> StringName:
	if not _loaded:
		return &""
	return StringName(_type_relations.get(_make_matchup_key(attacker_type, defender_type), &""))


## strength 仅表示一次合法感染尝试的成功概率，其他系统不应挪用。
func get_strength_success_probability(strength: int) -> float:
	return float(_strength_probabilities.get(strength, 0.0)) if _loaded else 0.0


## 返回费米原型时序和反击公开参数的值副本。
func get_opponent_config(opponent_id: String) -> Dictionary:
	if not _loaded:
		return {}
	var config: Dictionary = _opponent_configs.get(opponent_id, {})
	return config.duplicate(true)


## 将 21 表中费米启用技能映射成可讨论的 Plan B 行为候选。
func get_retaliation_skill_mappings(streamer_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _loaded:
		return result
	for mapping: Dictionary in _retaliation_mappings:
		if streamer_id.is_empty() or str(mapping.get("streamer_id", "")) == streamer_id:
			result.append(mapping.duplicate(true))
	return result


func is_loaded() -> bool:
	return _loaded


func _has_required_word_fields(row: Dictionary) -> bool:
	for field: String in [
		"word_id", "text", "battle_type", "strength", "traits", "tendency",
		"available_level", "available_to", "source_table", "source_id", "test_only",
	]:
		if not row.has(field):
			return false
	return true


func _has_complete_matchup_table() -> bool:
	var type_ids: Array[StringName] = []
	for relation_key: String in _type_relations:
		var halves: PackedStringArray = relation_key.split("|", false)
		if halves.size() != 2:
			return false
		for half: String in halves:
			var type_id := StringName(half)
			if not type_ids.has(type_id):
				type_ids.append(type_id)
	if type_ids.size() != 3:
		return false
	for attacker: StringName in type_ids:
		for defender: StringName in type_ids:
			if not _type_relations.has(_make_matchup_key(attacker, defender)):
				return false
	return true


func _make_matchup_key(attacker_type: Variant, defender_type: Variant) -> String:
	return "%s|%s" % [str(attacker_type), str(defender_type)]


func _parse_trait_ids(raw_value: String) -> Array[StringName]:
	var result: Array[StringName] = []
	var normalized: String = raw_value.strip_edges().to_lower()
	if normalized.is_empty() or normalized == "none" or normalized == "[]":
		return result
	for part: String in raw_value.split("|", false):
		var trait_id := StringName(part.strip_edges())
		if not String(trait_id).is_empty() and not result.has(trait_id):
			result.append(trait_id)
	return result


func _parse_opponent_config(row: Dictionary) -> Dictionary:
	var required_numbers: Dictionary = {
		"initial_speech_delay_seconds": 0.0,
		"speech_cooldown_seconds": 0.0,
		"counterattack_lead_margin": 0,
		"counterattack_cooldown_seconds": 0.0,
		"counterattack_pre_windup_seconds": 0.0,
		"counterattack_child_count": 0,
		"counterattack_max_uses": 0,
	}
	var parsed: Dictionary = {}
	for key: String in required_numbers:
		var raw_value: String = str(row.get(key, "")).strip_edges()
		if not raw_value.is_valid_float():
			return {}
		var numeric_value: float = float(raw_value)
		if key in ["counterattack_lead_margin", "counterattack_child_count", "counterattack_max_uses"]:
			if not raw_value.is_valid_int():
				return {}
			parsed[key] = int(raw_value)
		else:
			parsed[key] = numeric_value
	for key: String in [
		"level_id", "counterattack_skill_id", "counterattack_trigger_event", "counterattack_effect_id",
	]:
		parsed[key] = str(row.get(key, "")).strip_edges()
		if str(parsed[key]).is_empty():
			return {}
	parsed["speech_enabled"] = str(row.get("speech_enabled", "false")).to_lower() == "true"
	parsed["counterattack_enabled"] = str(row.get("counterattack_enabled", "false")).to_lower() == "true"
	parsed["test_only"] = str(row.get("test_only", "")).to_lower() == "true"
	parsed["notes"] = str(row.get("notes", ""))
	if not parsed["test_only"] or float(parsed["speech_cooldown_seconds"]) <= 0.0 \
		or float(parsed["counterattack_pre_windup_seconds"]) < 0.0:
		return {}
	return parsed


func _parse_retaliation_mapping(row: Dictionary) -> Dictionary:
	return {
		"skill_id": str(row.get("skill_id", "")),
		"streamer_id": str(row.get("streamer_id", "")),
		"tier": int(str(row.get("tier", "0"))) if str(row.get("tier", "")).is_valid_int() else 0,
		"trait_id": StringName(str(row.get("trait_id", ""))),
		"trait_name": str(row.get("trait_name", "")),
		"weight": int(str(row.get("weight", "0"))) if str(row.get("weight", "")).is_valid_int() else 0,
		"candidate_plan_b_behavior": str(row.get("candidate_plan_b_behavior", "")),
		"prototype_status": str(row.get("prototype_status", "")),
		"source_notes": str(row.get("source_notes", "")),
	}


func _read_csv_rows(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		push_error("PlanBContentCatalog: 找不到原型配置 %s" % path)
		return result
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("PlanBContentCatalog: 无法打开原型配置 %s" % path)
		return result
	var headers: PackedStringArray = file.get_csv_line()
	while not file.eof_reached():
		var cells: PackedStringArray = file.get_csv_line()
		if cells.size() == 1 and cells[0].is_empty():
			continue
		if cells.size() != headers.size():
			push_error("PlanBContentCatalog: CSV 列数不匹配 %s" % path)
			return []
		var row: Dictionary = {}
		for index: int in headers.size():
			row[str(headers[index])] = cells[index]
		result.append(row)
	return result
