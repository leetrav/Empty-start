class_name AttackChargeInput
extends Node

@export var charge_duration_seconds: float = 0.8

var _charge_progress: AttackChargeProgress
var _was_attack_held: bool = false


# 每帧累积按住时间；检测到未蓄满松开时只清空进度，不发射攻击事件。
func _process(delta: float) -> void:
	if _charge_progress == null:
		return

	var is_attack_held: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if is_attack_held:
		_charge_progress.advance(delta, true)
	elif _was_attack_held:
		_charge_progress.cancel_if_undercharged()

	_was_attack_held = is_attack_held


func _ready() -> void:
	_charge_progress = AttackChargeProgress.new(charge_duration_seconds)


# 提供给后续攻击反馈和释放流程读取当前蓄力比例。
func get_charge_progress() -> float:
	return _charge_progress.get_progress() if _charge_progress != null else 0.0


# 提供给后续释放流程判断是否已经蓄满。
func is_fully_charged() -> bool:
	return _charge_progress != null and _charge_progress.is_fully_charged()
