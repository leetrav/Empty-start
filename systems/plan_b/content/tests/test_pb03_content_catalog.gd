extends SceneTree

const ContentCatalogScript := preload("res://systems/plan_b/content/plan_b_content_catalog.gd")
const LEVEL_PATHS: Array[String] = [
	"res://data/level_configuration/level_001.tres",
	"res://data/level_configuration/level_002.tres",
	"res://data/level_configuration/level_003.tres",
	"res://data/level_configuration/level_004.tres",
]
const EXPECTED_OPPONENT_WORD_COUNTS: Array[int] = [5, 6, 5, 6]


func _init() -> void:
	var catalog = ContentCatalogScript.new()
	assert(catalog.load_configuration())
	assert(catalog.is_loaded())
	assert(catalog.get_word_ids("level_001", "player").size() == 163)
	assert(catalog.get_word_ids("level_002", "player").size() == 163)
	assert(catalog.get_word_ids("level_001", "unknown").is_empty())

	for index: int in LEVEL_PATHS.size():
		var level: LevelProfile = load(LEVEL_PATHS[index]) as LevelProfile
		assert(level != null)
		assert(catalog.configure_level(level))
		var context: Dictionary = catalog.get_current_level_context()
		assert(context["level_id"] == level.level_id)
		assert(context["streamer_id"] == level.streamer_id)
		assert(context["pool_id"] == level.normal_speech_pool_source.pool_id)
		assert(catalog.get_word_ids(level, "player").size() == 163)
		var opponent_word_ids: Array[String] = catalog.get_word_ids(level, "opponent")
		assert(opponent_word_ids.size() == EXPECTED_OPPONENT_WORD_COUNTS[index])
		assert(catalog.get_opponent_config()["streamer_id"] == level.streamer_id)
		for opponent_word_id: String in opponent_word_ids:
			assert(catalog.get_word_definition(opponent_word_id)["streamer_id"] == level.streamer_id)

	var no_used_words: Array[String] = []
	var used_player_words: Array[String] = ["w_0001"]
	assert(catalog.get_available_word_ids("player", no_used_words, "level_001").size() == 163)
	assert(catalog.get_available_word_ids("player", used_player_words, "level_001").size() == 162)
	var alien_opponent_word_ids: Array[String] = catalog.get_word_ids("level_001", "opponent")
	var used_opponent_words: Array[String] = [alien_opponent_word_ids[0]]
	assert(catalog.get_available_word_ids("opponent", used_opponent_words, "level_001").size() == 4)

	var definition: Dictionary = catalog.get_word_definition("w_0001")
	assert(definition["text"] == "天堂名额少，先点点关注！")
	assert(definition["battle_type"] == &"type_a")
	assert(definition["strength"] == 1)
	assert(definition["tendency"] == &"heretical")
	assert(definition["tendency_id"] == &"heretical")
	assert(definition["source_tendency"] == &"heresy")
	assert(definition["original_sentence_id"] == "w_0001")
	assert(definition["available_level"] == &"all")
	assert(definition["source_pool_id"] == "pool_streamer_a")
	assert(not definition["test_only"])
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

	var opponent_definition: Dictionary = catalog.get_word_definition(alien_opponent_word_ids[0])
	assert(opponent_definition["available_to"] == &"opponent")
	assert(opponent_definition["source_table"] == "20_主播气泡对白.csv")
	assert(opponent_definition["source_id"] == alien_opponent_word_ids[0])
	var mappings: Array[Dictionary] = catalog.get_retaliation_skill_mappings("alien")
	assert(mappings.size() == 8)
	assert(_find_mapping(mappings, "alien_t3_split").get("trait_name", "") == "分裂")
	assert(_find_mapping(mappings, "alien_t3_split").get("prototype_status", "") == "ACTIVE_PROFILE")
	assert(catalog.get_retaliation_skill_mappings().size() == 32)

	var alien_config: Dictionary = catalog.get_opponent_config("alien")
	assert(alien_config["level_id"] == "level_001")
	assert(is_equal_approx(float(alien_config["speech_cooldown_seconds"]), 11.5))
	assert(is_equal_approx(float(alien_config["counterattack_pre_windup_seconds"]), 1.2))
	assert(catalog.get_opponent_config("kiwi")["counterattack_skill_id"] == "kiwi_t3_retaliation_copy")
	assert(catalog.get_opponent_config("fox")["counterattack_effect_id"] == "split")
	assert(catalog.get_opponent_config("fermi").is_empty())
	alien_config["speech_cooldown_seconds"] = 0.0
	assert(is_equal_approx(float(catalog.get_opponent_config("alien")["speech_cooldown_seconds"]), 11.5))

	_test_hand_lifecycle(catalog)
	print("PB08_CONTENT_TEST_OK")
	quit()


func _test_hand_lifecycle(catalog: Object) -> void:
	var level: LevelProfile = load(LEVEL_PATHS[0]) as LevelProfile
	catalog.set_random_seed(731)
	assert(catalog.configure_level(level))
	var first_hand: Array[Dictionary] = catalog.get_player_hand()
	assert(first_hand.size() == 4)
	var first_ids: Array[String] = _hand_ids(first_hand)
	assert(_has_unique_ids(first_ids))

	# 未确认消耗的调用代表失败路径，既有手牌顺序保持原样。
	var no_used_word_ids: Array[String] = []
	var failed_result: Array[Dictionary] = catalog.consume_player_hand_word(first_ids[0], no_used_word_ids)
	assert(_hand_ids(failed_result) == first_ids)
	assert(_hand_ids(catalog.get_player_hand()) == first_ids)

	# 只有 A 的已用列表包含成功句时才消耗并补入一张新牌。
	var used_after_success: Array[String] = [first_ids[0]]
	var replenished: Array[Dictionary] = catalog.consume_player_hand_word(first_ids[0], used_after_success)
	var replenished_ids: Array[String] = _hand_ids(replenished)
	assert(replenished.size() == 4)
	assert(not replenished_ids.has(first_ids[0]))
	assert(_has_unique_ids(replenished_ids))
	assert(catalog.consume_player_hand_word(first_ids[0], used_after_success).size() == 4)

	# 同一 seed 与关卡重置回相同的可复现初始牌序。
	var reset_hand: Array[Dictionary] = catalog.reset_player_hand()
	assert(_hand_ids(reset_hand) == first_ids)

	# 最后两句可用时手牌按剩余数显示；耗尽后返回空列表。
	var all_player_ids: Array[String] = catalog.get_word_ids(level, "player")
	var used_except_two: Array[String] = []
	for word_id: String in all_player_ids:
		if word_id not in ["w_0001", "w_0002"]:
			used_except_two.append(word_id)
	var two_word_hand: Array[Dictionary] = catalog.reset_player_hand(used_except_two)
	assert(two_word_hand.size() == 2)
	var final_used_ids: Array[String] = used_except_two.duplicate()
	final_used_ids.append(str(two_word_hand[0]["word_id"]))
	var one_word_hand: Array[Dictionary] = catalog.consume_player_hand_word(
		str(two_word_hand[0]["word_id"]), final_used_ids
	)
	assert(one_word_hand.size() == 1)
	final_used_ids.append(str(one_word_hand[0]["word_id"]))
	assert(catalog.consume_player_hand_word(str(one_word_hand[0]["word_id"]), final_used_ids).is_empty())


func _hand_ids(hand: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for definition: Dictionary in hand:
		result.append(str(definition.get("word_id", "")))
	return result


func _has_unique_ids(word_ids: Array[String]) -> bool:
	var unique_ids: Dictionary = {}
	for word_id: String in word_ids:
		if unique_ids.has(word_id):
			return false
		unique_ids[word_id] = true
	return true


func _find_mapping(mappings: Array[Dictionary], skill_id: String) -> Dictionary:
	for mapping: Dictionary in mappings:
		if str(mapping.get("skill_id", "")) == skill_id:
			return mapping
	return {}
