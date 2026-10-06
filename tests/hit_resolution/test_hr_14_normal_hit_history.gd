extends SceneTree

const HitResolutionScript = preload("res://core/combat/hit_resolution.gd")


func _initialize() -> void:
	var hit_resolution = HitResolutionScript.new(0.5, 0.0, 1.0)
	hit_resolution.record_normal_word_hit("phrase-a", "orthodox")
	hit_resolution.record_normal_word_hit("phrase-b", "absurd")
	hit_resolution.record_normal_word_hit("phrase-a", "orthodox")
	var history: Array[Dictionary] = hit_resolution.get_normal_hit_history()
	var test_passed: bool = (
		history.size() == 2
		and history[0].get("original_sentence_id", "") == "phrase-a"
		and history[0].get("tendency", "") == "orthodox"
		and history[0].get("hit_count", 0) == 2
		and history[0].get("first_hit_order", 0) == 1
		and history[0].get("last_hit_order", 0) == 3
		and history[1].get("original_sentence_id", "") == "phrase-b"
	)
	if test_passed:
		print("PASS HR-14 repeated original sentence merges into one history record")
		quit(0)
	else:
		push_error("HR-14 normal hit history merge test failed.")
		quit(1)
