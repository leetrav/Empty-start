extends SceneTree

const HitResolutionScript = preload("res://core/combat/hit_resolution.gd")
const OpponentPKBarScript = preload("res://core/combat/opponent_pk_bar.gd")

var _failure_event_count: int = 0


func _initialize() -> void:
	var hit_resolution = HitResolutionScript.new(0.001, 0.0, 1.0)
	var opponent_pk_bar = OpponentPKBarScript.new()
	opponent_pk_bar.attempt_failed.connect(_on_attempt_failed)
	opponent_pk_bar.start_pullback(hit_resolution, 0.001)
	opponent_pk_bar._process(1.0)
	opponent_pk_bar._process(1.0)
	var test_passed: bool = (
		hit_resolution.get_player_pk() == 0.0
		and opponent_pk_bar.has_attempt_failed()
		and _failure_event_count == 1
	)
	opponent_pk_bar.free()
	if test_passed:
		print("PASS OP-05 zero PK marks one failed attempt")
		quit(0)
	else:
		push_error("OP-05 zero PK failure test failed.")
		quit(1)


func _on_attempt_failed() -> void:
	_failure_event_count += 1
