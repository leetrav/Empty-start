extends SceneTree

const ContentCatalogScript := preload("res://systems/plan_b/content/plan_b_content_catalog.gd")


func _initialize() -> void:
	var catalog = ContentCatalogScript.new()
	assert(catalog.load_test_configuration())
	assert(catalog.is_loaded())

	var player_word_ids: Array[String] = catalog.get_word_ids("level_001", "player")
	var opponent_word_ids: Array[String] = catalog.get_word_ids("level_001", "opponent")
	assert(player_word_ids.size() == 30)
	assert(opponent_word_ids.size() == 5)
	assert(catalog.get_word_ids("level_002", "player").is_empty())
	assert(catalog.get_word_ids("level_001", "unknown").is_empty())

	var definition: Dictionary = catalog.get_word_definition("w_0001")
	assert(definition["text"] == "天堂名额少，先点点关注！")
	assert(definition["battle_type"] == &"type_a")
	assert(definition["strength"] == 1)
	assert(definition["tendency"] == &"heresy")
	assert(definition["available_level"] == &"level_001")
	assert(definition["traits"].is_empty())
	definition["text"] = "caller changed only its snapshot"
	definition["traits"].append(&"caller_only")
	var unchanged: Dictionary = catalog.get_word_definition("w_0001")
	assert(unchanged["text"] == "天堂名额少，先点点关注！")
	assert(unchanged["traits"].is_empty())
	assert(catalog.get_word_definition("missing").is_empty())

	assert(catalog.get_type_matchup("type_a", "type_b") == &"advantage")
	assert(catalog.get_type_matchup("type_b", "type_c") == &"advantage")
	assert(catalog.get_type_matchup("type_c", "type_a") == &"advantage")
	assert(catalog.get_type_matchup("type_a", "type_a") == &"same")
	assert(catalog.get_type_matchup("type_b", "type_a") == &"disadvantage")
	assert(is_equal_approx(catalog.get_strength_success_probability(1), 0.20))
	assert(is_equal_approx(catalog.get_strength_success_probability(2), 0.35))
	assert(is_equal_approx(catalog.get_strength_success_probability(3), 0.50))
	assert(catalog.get_strength_success_probability(4) == 0.0)

	var opponent_definition: Dictionary = catalog.get_word_definition("pb_fermi_01")
	assert(opponent_definition["available_to"] == &"opponent")
	assert(opponent_definition["source_id"] == "bubble_alien_script_20261013_001")
	var mappings: Array[Dictionary] = catalog.get_retaliation_skill_mappings("alien")
	assert(mappings.size() == 8)
	assert(_find_mapping(mappings, "alien_t3_split").get("trait_name", "") == "分裂")
	assert(_find_mapping(mappings, "alien_t3_split").get("prototype_status", "") == "PB03_SPLIT_PROFILE")

	var opponent_config: Dictionary = catalog.get_opponent_config("fermi")
	assert(is_equal_approx(float(opponent_config["speech_cooldown_seconds"]), 11.5))
	assert(is_equal_approx(float(opponent_config["counterattack_pre_windup_seconds"]), 1.2))
	opponent_config["speech_cooldown_seconds"] = 0.0
	assert(is_equal_approx(float(catalog.get_opponent_config("fermi")["speech_cooldown_seconds"]), 11.5))
	print("PB03_CONTENT_TEST_OK")
	quit()


func _find_mapping(mappings: Array[Dictionary], skill_id: String) -> Dictionary:
	for mapping: Dictionary in mappings:
		if str(mapping.get("skill_id", "")) == skill_id:
			return mapping
	return {}
