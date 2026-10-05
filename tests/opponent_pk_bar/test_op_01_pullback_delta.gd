extends SceneTree

const OpponentPKBarScript = preload("res://core/combat/opponent_pk_bar.gd")


func _initialize() -> void:
	var opponent_pk_bar = OpponentPKBarScript.new()
	var failed_count: int = 0

	if not is_equal_approx(opponent_pk_bar.calculate_pullback_amount(0.005, 2.0), 0.01):
		push_error("OP-01 positive elapsed time must return speed multiplied by elapsed seconds.")
		failed_count += 1
	else:
		print("PASS OP-01 positive elapsed time")

	if not is_equal_approx(opponent_pk_bar.calculate_pullback_amount(0.005, 0.0), 0.0):
		push_error("OP-01 zero elapsed time must return zero pullback.")
		failed_count += 1
	else:
		print("PASS OP-01 zero elapsed time")

	quit(1 if failed_count > 0 else 0)
