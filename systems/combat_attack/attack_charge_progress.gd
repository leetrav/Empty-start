class_name AttackChargeProgress
extends RefCounted

var _duration_seconds: float
var _elapsed_seconds: float = 0.0


# 蓄力时长由攻击输入组件传入，状态对象只保存本次累计进度。
func _init(duration_seconds: float) -> void:
	_duration_seconds = duration_seconds


# 仅在攻击键持续按住时累积；不接收准心或候选目标，目标变化不会重置进度。
func advance(delta: float, is_attack_held: bool) -> void:
	if not is_attack_held or is_fully_charged():
		return

	_elapsed_seconds = minf(_duration_seconds, _elapsed_seconds + maxf(delta, 0.0))


# 未蓄满松开时取消本次蓄力；满蓄状态留给后续释放任务处理。
func cancel_if_undercharged() -> bool:
	if is_fully_charged():
		return false

	_elapsed_seconds = 0.0
	return true


# 蓄满释放后消费本次进度，为下一次蓄力周期复位。
func consume_fully_charged() -> bool:
	if not is_fully_charged():
		return false

	_elapsed_seconds = 0.0
	return true


# 把累计时长转换为 0 到 1 的蓄力比例。
func get_progress() -> float:
	if _duration_seconds <= 0.0:
		return 1.0
	return clampf(_elapsed_seconds / _duration_seconds, 0.0, 1.0)


# 蓄力达到配置时长后保持满蓄状态。
func is_fully_charged() -> bool:
	return _duration_seconds <= 0.0 or _elapsed_seconds >= _duration_seconds
