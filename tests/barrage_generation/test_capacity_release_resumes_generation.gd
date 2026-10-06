extends SceneTree

const CAPACITY_LEDGER_SCRIPT = preload("res://systems/barrage_generation/barrage_capacity_ledger.gd")

# 释放陷阱占位后，普通占用者应拿到腾出的容量。
func _init() -> void:
	var capacity_ledger: Object = CAPACITY_LEDGER_SCRIPT.new()
	var trap_occupant: RefCounted = RefCounted.new()
	var normal_occupant: RefCounted = RefCounted.new()
	var slot_filled: bool = bool(capacity_ledger.call("try_register", trap_occupant, 1))
	var full_before_release: bool = not bool(capacity_ledger.call("has_capacity", 1))
	var slot_released: bool = bool(capacity_ledger.call("release", trap_occupant))
	var slot_open_after_release: bool = bool(capacity_ledger.call("has_capacity", 1))
	var normal_capacity_reopened: bool = bool(capacity_ledger.call("try_register", normal_occupant, 1))
	var passed: bool = slot_filled and full_before_release and slot_released and slot_open_after_release and normal_capacity_reopened
	if passed:
		print("PASS: 释放容量后普通容量请求通过。")
	else:
		push_error("FAIL: 释放容量后普通容量仍被占满。")
	quit(0 if passed else 1)
