extends SceneTree

const OpponentPKBarScript = preload("res://core/combat/opponent_pk_bar.gd")


func _initialize() -> void:
	var failed_count: int = 0
	if not _test_failure_increments_streak():
		push_error("OP-09 failure must increment the current-level loss streak.")
		failed_count += 1
	else:
		print("PASS OP-09 failure increments streak")

	if not _test_level_completion_resets_streak():
		push_error("OP-09 level completion must reset the loss streak.")
		failed_count += 1
	else:
		print("PASS OP-09 level completion resets streak")

	if not _test_new_run_resets_streak():
		push_error("OP-09 a new run must reset the loss streak.")
		failed_count += 1
	else:
		print("PASS OP-09 new run resets streak")

	quit(1 if failed_count > 0 else 0)


func _test_failure_increments_streak() -> bool:
	var opponent_pk_bar = OpponentPKBarScript.new()
	opponent_pk_bar.record_current_level_failure()
	var test_passed: bool = opponent_pk_bar.get_loss_streak_count() == 1
	opponent_pk_bar.free()
	return test_passed


func _test_level_completion_resets_streak() -> bool:
	var opponent_pk_bar = OpponentPKBarScript.new()
	opponent_pk_bar.record_current_level_failure()
	opponent_pk_bar.record_current_level_failure()
	opponent_pk_bar.complete_current_level()
	var test_passed: bool = opponent_pk_bar.get_loss_streak_count() == 0
	opponent_pk_bar.free()
	return test_passed


func _test_new_run_resets_streak() -> bool:
	var opponent_pk_bar = OpponentPKBarScript.new()
	opponent_pk_bar.record_current_level_failure()
	opponent_pk_bar.start_new_run()
	var test_passed: bool = opponent_pk_bar.get_loss_streak_count() == 0
	opponent_pk_bar.free()
	return test_passed
