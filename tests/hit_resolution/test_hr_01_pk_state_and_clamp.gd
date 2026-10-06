extends SceneTree

const HitResolutionScript = preload("res://core/combat/hit_resolution.gd")


func _initialize() -> void:
	var failed_count: int = 0
	if not _test_pk_below_minimum_clamps_to_minimum():
		push_error("HR-01 lower-bound test failed.")
		failed_count += 1
	else:
		print("PASS HR-01 lower-bound clamp")

	if not _test_pk_above_maximum_clamps_to_maximum():
		push_error("HR-01 upper-bound test failed.")
		failed_count += 1
	else:
		print("PASS HR-01 upper-bound clamp")

	if failed_count > 0:
		quit(1)
	else:
		quit(0)


func _test_pk_below_minimum_clamps_to_minimum() -> bool:
	var hit_resolution = HitResolutionScript.new(0.5, 0.0, 1.0)
	var final_pk: float = hit_resolution.apply_player_pk_delta(-0.75)
	return is_equal_approx(final_pk, 0.0) and is_equal_approx(hit_resolution.get_player_pk(), 0.0)


func _test_pk_above_maximum_clamps_to_maximum() -> bool:
	var hit_resolution = HitResolutionScript.new(0.5, 0.0, 1.0)
	var final_pk: float = hit_resolution.apply_player_pk_delta(0.75)
	return is_equal_approx(final_pk, 1.0) and is_equal_approx(hit_resolution.get_player_pk(), 1.0)
