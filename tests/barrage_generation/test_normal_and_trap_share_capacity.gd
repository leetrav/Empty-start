extends SceneTree

const CAPACITY_LEDGER_SCRIPT = preload("res://systems/barrage_generation/normal_barrage_capacity_ledger.gd")

# 使用轻量对象区分陷阱与话语占位，验证它们共用同一上限。
func _init() -> void:
	var shared_ledger: Object = CAPACITY_LEDGER_SCRIPT.new()
	var trap_occupant: RefCounted = RefCounted.new()
	var speech_occupant: RefCounted = RefCounted.new()
	var extra_trap_occupant: RefCounted = RefCounted.new()
	var trap_registered: bool = bool(shared_ledger.call("try_register", trap_occupant, 2))
	var speech_registered: bool = bool(shared_ledger.call("try_register", speech_occupant, 2))
	var extra_trap_rejected: bool = not bool(shared_ledger.call("try_register", extra_trap_occupant, 2))
	var shared_capacity_reached: bool = not bool(shared_ledger.call("has_capacity", 2))
	var passed: bool = trap_registered and speech_registered and extra_trap_rejected and shared_capacity_reached
	if passed:
		print("PASS: 普通话语与陷阱占用同一容量。")
	else:
		push_error("FAIL: 普通话语与陷阱未共享容量。")
	quit(0 if passed else 1)
