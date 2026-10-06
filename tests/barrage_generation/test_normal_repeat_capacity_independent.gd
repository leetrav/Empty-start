extends SceneTree

const CAPACITY_LEDGER_SCRIPT = preload("res://systems/barrage_generation/barrage_capacity_ledger.gd")

func _init() -> void:
	var normal_capacity: Object = CAPACITY_LEDGER_SCRIPT.new()
	var repeat_capacity: Object = CAPACITY_LEDGER_SCRIPT.new()
	var normal_barrage: RefCounted = RefCounted.new()
	var repeat_barrage: RefCounted = RefCounted.new()
	var normal_accepted: bool = bool(normal_capacity.call("try_register", normal_barrage, 1))
	var repeat_accepted: bool = bool(repeat_capacity.call("try_register", repeat_barrage, 1))
	var normal_full: bool = not bool(normal_capacity.call("has_capacity", 1))
	var repeat_full: bool = not bool(repeat_capacity.call("has_capacity", 1))
	var normal_released: bool = bool(normal_capacity.call("release", normal_barrage))
	var normal_open_again: bool = bool(normal_capacity.call("has_capacity", 1))
	var repeat_stays_full: bool = not bool(repeat_capacity.call("has_capacity", 1))
	var passed: bool = normal_accepted and repeat_accepted and normal_full and repeat_full and normal_released and normal_open_again and repeat_stays_full
	if passed:
		print("PASS: 普通与复读容量独立计算。")
	else:
		push_error("FAIL: 普通与复读容量发生串扰。")
	quit(0 if passed else 1)
