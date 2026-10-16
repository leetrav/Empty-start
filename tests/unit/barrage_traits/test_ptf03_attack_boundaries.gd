extends SceneTree

const ATTACK = preload("res://systems/combat_attack/attack_charge_input.gd")
const NUMERICS = preload("res://data/combat_stage/combat_numerics.tres")
var failures: int = 0
var first_held: int = 0
var released_at: int = 0


## 验证明确复现的吞按住/暂停残留；不以此替代人工手感验收。
func _initialize() -> void:
	call_deferred("_run")


## 失败给出明确进程结果，沿用直属测试写法。
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


## 使用生产 Timer 与公开手势接口，不改正式0.8/0.2/0.15秒。
func _run() -> void:
	var baseline: bool = OS.get_cmdline_user_args().has("--v0")
	var attack = load("res://.godot/ptf03_v0_attack.gd").new() if baseline else ATTACK.new()
	root.add_child(attack)
	attack.configure_attack_timing(NUMERICS.create_attack_timing_config())
	var phases: Array[int] = []
	if not baseline:
		attack.charge_state_changed.connect(func(_p: float, _h: bool, _f: bool, phase: int) -> void: phases.append(phase))
	attack.shot_arrival_resolved.connect(func(_s: AttackTargetSnapshot, _r: Array[Dictionary]) -> void: print("PTF03_TIMER arrival_wall_ms=",Time.get_ticks_msec()-released_at))
	await create_timer(0.3).timeout
	first_held=Time.get_ticks_msec()
	_pointer(attack,true)
	for frame: int in range(180):
		if attack.is_fully_charged(): break
		await process_frame
	print("PTF03_TIMER held_wall_ms=",Time.get_ticks_msec()-first_held)
	released_at=Time.get_ticks_msec()
	_pointer(attack,false)
	_check(attack.get_attack_phase()==1, "真实满蓄发射")
	await create_timer(NUMERICS.projectile_flight_seconds + 0.02).timeout
	_check(attack.get_attack_phase() == AttackChargeInput.AttackPhase.RECOVERY, "实际进入硬直")
	_pointer(attack,true)
	await create_timer(NUMERICS.recovery_time_seconds + 0.08).timeout
	_check(attack.is_charge_held() and attack.get_charge_progress() > 0.0, "READY后自动开始蓄力")
	paused = true
	_pointer(attack,false)
	_check(attack.get_charge_progress() == 0.0 and not attack.is_charge_held(), "暂停抬手清除蓄力")
	paused = false
	if baseline:
		print("PTF03_V0_FINISH failures=",failures)
		attack.queue_free()
		await process_frame
		quit(0 if failures==0 else 1)
		return
	attack.set_native_touch_input_enabled(false)
	_check(attack.begin_pointer_attack(Vector2.ZERO, true), "外部触摸接管")
	await create_timer(0.1).timeout
	attack.cancel_pointer_attack()
	_check(not attack.is_charge_held() and attack.get_charge_progress() == 0.0, "外部手势取消无残留")
	_check(phases.has(1) and phases.has(2) and phases.has(0), "公开真实阶段事件")
	attack.queue_free()
	await process_frame
	print("PTF03_ATTACK_PASS" if failures == 0 else "PTF03_ATTACK_FAIL")
	quit(0 if failures == 0 else 1)


## 同一实际输入分发复现V0与修复版，基线文件仅在.gitignore缓存内。
func _pointer(_attack: Node, held: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=held
	event.position=Vector2.ZERO
	Input.parse_input_event(event)
	Input.flush_buffered_events()
