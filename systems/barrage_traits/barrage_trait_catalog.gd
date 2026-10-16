class_name BarrageTraitCatalog
extends RefCounted

const TRAIT_TABLE_PATH := "res://data/source_tables/07_特性参数.csv"
const SKILL_TABLE_PATH := "res://data/source_tables/21_反击技能池.csv"

var _traits: Dictionary = {}
var _skills: Array[Dictionary] = []
var _assets: Dictionary = {}


## 生产配置直接读取源 CSV，保留策划字段为唯一真相源。
func load_production_tables() -> bool:
	_traits = _read_table(TRAIT_TABLE_PATH, "trait_id")
	_assets = _read_table("res://data/source_tables/18_表现资产.csv", "asset_id")
	_skills.clear()
	for row: Dictionary in _read_rows(SKILL_TABLE_PATH):
		if row.get("enabled", "").to_lower() != "true":
			continue
		if int(row.get("weight", "0")) <= 0:
			continue
		_skills.append(row)
	return not _traits.is_empty() and not _skills.is_empty()


## 按主播与当前 Tier 过滤，再按表内权重抽取一项启用技能。
func choose_skill(streamer_id: String, tier: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var total_weight: float = 0.0
	for row: Dictionary in _skills:
		if row.get("streamer_id", "") == streamer_id and int(row.get("tier", "-1")) == tier:
			candidates.append(row)
			total_weight += float(row.get("weight", "0"))
	if candidates.is_empty() or total_weight <= 0.0:
		return {}
	var roll: float = rng.randf_range(0.0, total_weight) if rng != null else randf_range(0.0, total_weight)
	for row: Dictionary in candidates:
		roll -= float(row.get("weight", "0"))
		if roll < 0.0:
			return row.duplicate()
	return candidates.back().duplicate()


## 将技能的特性 ID 转成 BarrageArea 现有装配入口可消费的类型化列表。
func get_skill_trait_ids(skill: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	if skill.get("skill_type", "") != "trait":
		return result
	for raw_id: String in str(skill.get("trait_ids", "")).split("|", false):
		var trait_id := StringName(raw_id.strip_edges())
		if _traits.has(String(trait_id)) and not result.has(trait_id):
			result.append(trait_id)
	return result


## 返回 07 表字段快照，数值由现有命中与生命周期拥有者解释。
func get_trait_definition(trait_id: StringName) -> Dictionary:
	return (_traits.get(String(trait_id), {}) as Dictionary).duplicate()


## 返回正式启用候选的副本，调用方可逐条展示或验收，不参与第二次随机。
func get_enabled_skills(streamer_id: String = "", tier: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for skill: Dictionary in _skills:
		if not streamer_id.is_empty() and str(skill.get("streamer_id", "")) != streamer_id:
			continue
		if tier >= 0 and int(skill.get("tier", "-1")) != tier:
			continue
		result.append(skill.duplicate(true))
	return result


## 将 07 的实例规则交给独立 TraitSet，静态 CSV 和其他实例保持只读。
func configure_trait_set(trait_set: BarrageTraitSet) -> void:
	var definitions: Dictionary = {}
	for trait_id: StringName in trait_set.get_trait_ids():
		definitions[trait_id] = get_trait_definition(trait_id)
	trait_set.configure_definitions(definitions)


## 沿用现有生成器的装配顺序，首个有效寿命覆盖优先；不新增叠加规则。
func get_lifetime_override(trait_ids: Array[StringName]) -> float:
	for trait_id: StringName in trait_ids:
		var value: String = str(get_trait_definition(trait_id).get("lifetime_override_s", ""))
		if value.is_valid_float() and float(value) > 0.0:
			return float(value)
	return 0.0


## 通过 18 表原 ID 返回资产事实；缺行和目录占位保持显式缺失，供 E 补映射。
func get_visual_asset_status(trait_id: StringName) -> Dictionary:
	var asset_id: String = str(get_trait_definition(trait_id).get("visual_asset_id", ""))
	var asset: Dictionary = _assets.get(asset_id, {})
	return {"trait_id": trait_id, "visual_asset_id": asset_id, "asset_row": asset.duplicate(true),
		"missing_mapping": asset.is_empty()}


func get_trait_count() -> int:
	return _traits.size()


func get_enabled_skill_count() -> int:
	return _skills.size()


func _read_table(path: String, key: String) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in _read_rows(path):
		var id: String = str(row.get(key, ""))
		if not id.is_empty():
			result[id] = row
	return result


func _read_rows(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		push_error("BarrageTraitCatalog: 找不到正式表 %s" % path)
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	var headers: PackedStringArray = file.get_csv_line()
	while not file.eof_reached():
		var values: PackedStringArray = file.get_csv_line()
		if values.size() != headers.size():
			continue
		var row: Dictionary = {}
		for index: int in headers.size():
			row[headers[index]] = values[index]
		result.append(row)
	return result
