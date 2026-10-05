class_name AttackChargeInput
extends Node

@export var charge_duration_seconds: float = 0.8

var _charge_progress: AttackChargeProgress


# 每帧读取鼠标左键按住状态；此状态不依赖准心或当前候选目标。
func _process(delta: float) -> void:
	if _charge_progress == null:
		return
	_charge_progress.advance(delta, Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))


func _ready() -> void:
	_charge_progress = AttackChargeProgress.new(charge_duration_seconds)


# 提供给后续攻击反馈和释放流程读取当前蓄力比例。
func get_charge_progress() -> float:
	return _charge_progress.get_progress() if _charge_progress != null else 0.0


# 提供给后续释放流程判断是否已经蓄满。
func is_fully_charged() -> bool:
	return _charge_progress != null and _charge_progress.is_fully_charged()
