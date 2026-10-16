extends SceneTree

const ATTACK = preload("res://systems/combat_attack/attack_charge_input.gd")
const NUMERICS = preload("res://data/combat_stage/combat_numerics.tres")
var failures: int = 0


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
	var attack = ATTACK.new()
	root.add_child(attack)
	attack.configure_attack_timing(NUMERICS.create_attack_timing_config())
	var phases: Array[int] = []
	attack.charge_state_changed.connect(func(_p: float, _h: bool, _f: bool, phase: int) -> void: phases.append(phase))
	_check(attack.begin_pointer_attack(Vector2.ZERO), "开始蓄力")
	await create_timer(0.85).timeout
	_check(attack.end_pointer_attack(Vector2.ZERO), "真实满蓄发射")
	await create_timer(NUMERICS.projectile_flight_seconds + 0.02).timeout
	_check(attack.get_attack_phase() == AttackChargeInput.AttackPhase.RECOVERY, "实际进入硬直")
	_check(attack.begin_pointer_attack(Vector2.ZERO), "硬直期间保留新按住意图")
	await create_timer(NUMERICS.recovery_time_seconds + 0.08).timeout
	_check(attack.is_charge_held() and attack.get_charge_progress() > 0.0, "READY后自动开始蓄力")
	paused = true
	attack.end_pointer_attack(Vector2.ZERO)
	_check(attack.get_charge_progress() == 0.0 and not attack.is_charge_held(), "暂停抬手清除蓄力")
	paused = false
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
