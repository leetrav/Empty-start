extends SceneTree

const VIEW = preload("res://systems/barrage_generation/barrage_view.tscn")
var failures: int = 0


## 用真实墙钟跨过实例剩余寿命，检查实际View暂停补偿而非短Timer冒烟。
func _initialize() -> void:
	call_deferred("_run")


## 暂停时SceneTree仍广播帧；等待真实毫秒，避免把模拟时间当绝对期限。
func _wait_wall_msec(duration: int) -> void:
	var until: int = Time.get_ticks_msec() + duration
	while Time.get_ticks_msec() < until:
		await process_frame


## 测试入口只汇总外部可见行为，失败明确退出。
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


## 五种真实运行记录共用生产View，余寿命0.6秒，实际暂停2秒后继续存活。
func _run() -> void:
	var area := Control.new()
	root.add_child(area)
	area.size = Vector2(1024, 1008)
	var views: Array[BarrageView] = []
	for kind: StringName in [&"normal", &"split", &"retaliation_copy", &"repeat", &"contradiction"]:
		var facts := BarrageRuntimeRecord.new()
		facts.text = String(kind)
		facts.is_repeat = kind == &"repeat"
		facts.is_contradiction = kind == &"contradiction"
		facts.trait_set.add_trait(kind)
		facts.capture_lifetime_at_spawn(Time.get_ticks_msec(), 0.6, 1.0)
		var view := VIEW.instantiate() as BarrageView
		view.setup(facts, 0.0, area, true)
		area.add_child(view)
		view.position = Vector2(200, 50 + views.size() * 130)
		views.append(view)
		_check(view.process_mode == Node.PROCESS_MODE_ALWAYS, "生产View需在SceneTree暂停时继续记录期限补偿")
	await _wait_wall_msec(60)
	var before: Array[int] = []
	var alpha: Array[float] = []
	for view: BarrageView in views:
		before.append(view.runtime_record.expires_at_msec - Time.get_ticks_msec())
		alpha.append(view.modulate.a)
	paused = true
	await _wait_wall_msec(2000)
	for view: BarrageView in views:
		_check(is_instance_valid(view) and not view.is_queued_for_deletion(), "长暂停中实例不能自然结束")
	paused = false
	# 等实际View消费恢复帧；不直接改写它的运行记录或调用内部补偿方法。
	await process_frame
	await process_frame
	for index: int in views.size():
		var view: BarrageView = views[index]
		_check(is_instance_valid(view) and not view.is_queued_for_deletion(), "跨过原截止后恢复仍存活")
		if not is_instance_valid(view):
			continue
		var remaining: int = view.runtime_record.expires_at_msec - Time.get_ticks_msec()
		_check(remaining > 300 and abs(remaining - before[index]) < 150, "恢复时保留原剩余寿命，允许真实帧误差")
		_check(view.runtime_record.lifetime_duration_msec == 600, "补偿不重置完整寿命")
		if view.runtime_record.is_repeat:
			_check(absf(view.modulate.a - alpha[index]) < 0.25, "复读透明度暂停后继续而非突变为零")
		print("PTF03_PAUSE kind=%s remaining_before=%d remaining_after=%d" % [view.runtime_record.text, before[index], remaining])
	area.queue_free()
	await process_frame
	print("PTF03_LONG_PAUSE_PASS wall_pause_ms=2000 initial_lifetime_ms=600" if failures == 0 else "PTF03_LONG_PAUSE_FAIL")
	quit(0 if failures == 0 else 1)
