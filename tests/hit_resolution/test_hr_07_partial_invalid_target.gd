extends SceneTree

const HitResolutionScript = preload("res://core/combat/hit_resolution.gd")


func _initialize() -> void:
	var hit_resolution = HitResolutionScript.new(0.5, 0.0, 1.0)
	var target_validity: Array[bool] = [true, false, false]
	var should_apply_miss: bool = hit_resolution.is_shot_fully_missed(target_validity)
	if should_apply_miss:
		push_error("HR-07 invalid targets must not add a miss when another target is valid.")
		quit(1)
	else:
		print("PASS HR-07 partial invalid targets do not create a miss")
		quit(0)
