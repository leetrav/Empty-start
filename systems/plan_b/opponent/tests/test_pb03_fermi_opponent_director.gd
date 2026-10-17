extends SceneTree

const ContentCatalogScript := preload("res://systems/plan_b/content/plan_b_content_catalog.gd")
const OpponentDirectorScript := preload("res://systems/plan_b/opponent/fermi_opponent_director.gd")


func _initialize() -> void:
	var catalog = ContentCatalogScript.new()
	assert(catalog.load_test_configuration())
	var director = OpponentDirectorScript.new()
	assert(director.configure(catalog, 20261017))

	var speech_requests: Array[Dictionary] = []
	director.publish_word_requested.connect(
		func(word_id: String, unit_id: String) -> void:
			speech_requests.append({"word_id": word_id, "neutral_unit_id": unit_id})
	)
	var neutral_snapshots: Array[Dictionary] = [
		{"unit_id": "viewer_neutral_01", "team": "neutral"},
		{"unit_id": "viewer_player_01", "team": "player"},
	]
	var opponent_word_ids: Array[String] = catalog.get_word_ids("level_001", "opponent")
	director.update_speech(11.49, neutral_snapshots, opponent_word_ids)
	assert(speech_requests.is_empty())
	director.update_speech(0.02, neutral_snapshots, opponent_word_ids)
	assert(speech_requests.size() == 1)
	assert(opponent_word_ids.has(str(speech_requests[0]["word_id"])))
	assert(speech_requests[0]["neutral_unit_id"] == "viewer_neutral_01")
	# 请求本身不会修改 C 的词池，发表去重由 A 保存与裁决。
	assert(catalog.get_word_ids("level_001", "opponent").size() == 5)
	var no_neutrals: Array[Dictionary] = []
	director.update_speech(11.5, no_neutrals, opponent_word_ids)
	assert(speech_requests.size() == 1)
	director.update_speech(0.0, neutral_snapshots, opponent_word_ids)
	assert(speech_requests.size() == 2)

	var warnings: Array[Dictionary] = []
	var effect_requests: Array[Dictionary] = []
	var resolved: Array[Dictionary] = []
	director.counterattack_windup_started.connect(func(request: Dictionary) -> void: warnings.append(request))
	director.counterattack_resolved.connect(func(result: Dictionary) -> void: resolved.append(result))
	director.set_counterattack_effect_handler(
		func(request: Dictionary) -> bool:
			effect_requests.append(request)
			return str(request.get("effect_id", "")) == "split"
	)
	var opponent_snapshots: Array[Dictionary] = [{"unit_id": "fermi_unit_01", "team": "opponent"}]
	director.counterattack_enabled = false
	director.update_counterattack(0.0, {"player": 3, "opponent": 1}, opponent_snapshots)
	assert(warnings.is_empty())
	director.counterattack_enabled = true
	director.update_counterattack(0.0, {"player": 3, "opponent": 1, "neutral": 4}, opponent_snapshots)
	assert(warnings.size() == 1)
	assert(warnings[0]["skill_id"] == "alien_t3_split")
	assert(warnings[0]["effect_parameters"]["child_count"] == 2)
	assert(effect_requests.is_empty())
	director.update_counterattack(1.19, {"player": 3, "opponent": 1}, opponent_snapshots)
	assert(effect_requests.is_empty())
	director.update_counterattack(0.02, {"player": 3, "opponent": 1}, opponent_snapshots)
	assert(effect_requests.size() == 1)
	assert(effect_requests[0]["target_unit_id"] == "fermi_unit_01")
	# 注入执行器已经同步回报完成，重复结果不应再次计数。
	assert(not director.report_counterattack_result(true))
	director.update_counterattack(0.0, {"player": 3, "opponent": 1}, opponent_snapshots)
	assert(warnings.size() == 1)
	assert(resolved.size() == 1)
	assert(resolved[0]["applied"])
	assert(director.get_debug_snapshot()["counterattack_uses"] == 1)
	assert(not director.report_counterattack_result(true))
	print("PB03_OPPONENT_TEST_OK")
	quit()
