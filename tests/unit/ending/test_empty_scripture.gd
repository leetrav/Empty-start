extends SceneTree

const DISPLAY_DATA = preload("res://core/ending/ending_display_data.gd")
const MAIN_ART_CONFIG = preload("res://data/ending/ending_main_art_config.gd")
const RELIGION_NAME_CONFIG = preload("res://data/ending/ending_religion_name_config.gd")
const JUDGEMENT_TEXT_CONFIG = preload("res://data/ending/ending_judgement_text_config.gd")
const OPENING_IDENTITY = preload("res://data/identity/identity_orthodox_placeholder.tres")
const SCRIPTURE_DISPLAY = preload("res://core/ending/ending_scripture_display_data.gd")
const CLASSIFIER = preload("res://core/ending/ending_identity_result_classifier.gd")


# 只执行 EN-07 的一个关键用例：全空圣典仍组装结局数据。
func _initialize() -> void:
	if not _test_empty_scripture_still_builds_ending_data():
		quit(1)
		return
	print("PASS EN-07: 1 empty-scripture ending-data case")
	quit(0)


# 样本文本和主图只注入测试 Resource 实例，生产资源文件保持原状。
func _test_empty_scripture_still_builds_ending_data() -> bool:
	var state: TendencyState = TendencyState.new()
	state.initialize_from_identity_option(OPENING_IDENTITY)
	var scripture: ScriptureData = ScriptureData.new()
	var catalog: LevelCatalog = LevelCatalog.new()
	var level: LevelProfile = LevelProfile.new()
	level.level_id = "test_en07_level"
	level.level_order = 3
	catalog.profiles.append(level)
	var main_art_config = MAIN_ART_CONFIG.new()
	var religion_name_config = RELIGION_NAME_CONFIG.new()
	var judgement_text_config = JUDGEMENT_TEXT_CONFIG.new()
	var sample_art: Texture2D = GradientTexture2D.new()
	main_art_config.orthodox_main_art = sample_art
	religion_name_config.orthodox_name = "TEST_EN07_RELIGION_NAME"
	judgement_text_config.no_effective_behavior_text = "TEST_EN07_JUDGEMENT_TEXT"
	var builder = DISPLAY_DATA.new()
	var result: Dictionary = builder.build(
		state, scripture, catalog, main_art_config, religion_name_config, judgement_text_config
	)
	if (
		result.get("main_art") != sample_art
		or result.get("religion_name") != "TEST_EN07_RELIGION_NAME"
		or result.get("judgement_text") != "TEST_EN07_JUDGEMENT_TEXT"
	):
		push_error("EN-07 全空圣典丢失配置主图、教名或判词")
		return false
	if (
		result.get("identity_result_class") != CLASSIFIER.NO_EFFECTIVE_BEHAVIOR
		or result.get("primary_tendency_id") != "orthodox"
		or result.get("secondary_tendency_id") != "orthodox"
	):
		push_error("EN-07 未沿用现有分类或倾向查询结果")
		return false
	var section: Dictionary = result["scripture"]
	var rows: Array[Dictionary] = section["rows"]
	if (
		not section["is_empty"]
		or section["status"] != SCRIPTURE_DISPLAY.STATUS_NOT_FORMED_ORACLE
		or rows.size() != 1
	):
		push_error("EN-07 经文区域未得到空圣典状态及缺章")
		return false
	if (
		rows[0]["has_oracle"]
		or rows[0]["status"] != SCRIPTURE_DISPLAY.STATUS_NOT_FORMED_ORACLE
		or rows[0]["chapter_number"] != 3
		or rows[0]["verse_number"] != 0
	):
		push_error("EN-07 未保留 EN-04 的缺章显示数据")
		return false
	# 同一空圣典用例使用默认空配置再次组装，允许正式资源后续独立填写文案。
	var empty_config_result: Dictionary = builder.build(
		state, scripture, catalog,
		MAIN_ART_CONFIG.new(), RELIGION_NAME_CONFIG.new(), JUDGEMENT_TEXT_CONFIG.new()
	)
	if (
		not empty_config_result.has("main_art")
		or empty_config_result["main_art"] != null
		or empty_config_result.get("religion_name") != ""
		or empty_config_result.get("judgement_text") != ""
		or not empty_config_result["scripture"]["is_empty"]
	):
		push_error("EN-07 默认空配置阻断数据或被写入样本文本")
		return false
	if not scripture.get_ordered_entries().is_empty() or not state.has_no_effective_behavior():
		push_error("EN-07 显示组装修改了上游结果")
		return false
	return true
