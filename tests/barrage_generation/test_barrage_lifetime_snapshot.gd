extends SceneTree

const RUNTIME_RECORD_SCRIPT = preload("res://systems/barrage_generation/barrage_runtime_record.gd")

# 验证旧记录固定和新记录读取当前寿命，不启动完整战斗场景。
func _init() -> void:
	var passed_count: int = 0

	var old_barrage_record: BarrageRuntimeRecord = RUNTIME_RECORD_SCRIPT.new() as BarrageRuntimeRecord
	old_barrage_record.capture_lifetime_at_spawn(1000, 10.0, 1.0)
	var original_deadline: int = old_barrage_record.expires_at_msec
	var next_barrage_record: BarrageRuntimeRecord = RUNTIME_RECORD_SCRIPT.new() as BarrageRuntimeRecord
	next_barrage_record.capture_lifetime_at_spawn(2000, 10.0, 2.0)
	var old_deadline_unchanged: bool = old_barrage_record.expires_at_msec == original_deadline and original_deadline == 11000
	if old_deadline_unchanged:
		passed_count += 1
		print("PASS: 已生成弹幕的截止时间保持原值。")
	else:
		push_error("FAIL: 配置变化改写了旧弹幕截止时间。")

	var new_barrage_record: BarrageRuntimeRecord = RUNTIME_RECORD_SCRIPT.new() as BarrageRuntimeRecord
	new_barrage_record.capture_lifetime_at_spawn(2000, 10.0, 1.5)
	var new_record_uses_current_lifetime: bool = new_barrage_record.expires_at_msec == 17000
	if new_record_uses_current_lifetime:
		passed_count += 1
		print("PASS: 新实例使用生成时的寿命配置。")
	else:
		push_error("FAIL: 新实例未使用当前寿命配置。")

	print("BG-06: %d/2 tests passed." % passed_count)
	quit(0 if passed_count == 2 else 1)
