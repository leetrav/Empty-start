extends SceneTree

const HitResolutionScript = preload("res://core/combat/hit_resolution.gd")


func _initialize() -> void:
	if _test_target_deltas_aggregate_before_pk_clamp():
		print("PASS HR-05 aggregate target deltas before one PK update")
		quit(0)
	else:
		push_error("HR-05 shot aggregation test failed.")
		quit(1)


func _test_target_deltas_aggregate_before_pk_clamp() -> bool:
	var hit_resolution = HitResolutionScript.new(0.998, 0.0, 1.0)
	var target_results: Array[Dictionary] = [
		{"pk_delta": 0.005, "tendency_delta": 10},
		{"pk_delta": -0.005, "tendency_delta": 0},
	]
	var shot_result: Dictionary = hit_resolution.resolve_shot_results(target_results)
	var resolved_targets: Array = shot_result.get("target_results", [])
	return (
		is_equal_approx(shot_result.get("total_pk_delta", 1.0), 0.0)
		and is_equal_approx(shot_result.get("final_player_pk", -1.0), 0.998)
		and is_equal_approx(hit_resolution.get_player_pk(), 0.998)
		and resolved_targets.size() == 2
		and resolved_targets[0].get("tendency_delta", 0) == 10
		and resolved_targets[1].get("tendency_delta", -1) == 0
	)
