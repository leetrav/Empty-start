extends Node

var opacity: float = 1.0
var hold_fraction: float = 0.7


# 在原生 BarrageView 更新之后应用表现曲线；仍读取同一到期/暂停补偿记录。
func _ready() -> void:
	process_priority = 1


# 前段保持可读亮度，最后一段平滑淡出；不改写出生/到期时间或容量账本。
func _process(_delta: float) -> void:
	var view := get_parent() as BarrageView
	if view == null or view.runtime_record == null or view.runtime_record.lifetime_duration_msec <= 0:
		return
	var remaining := maxi(view.runtime_record.expires_at_msec - Time.get_ticks_msec(), 0)
	var age := 1.0 - clampf(float(remaining) / float(view.runtime_record.lifetime_duration_msec), 0.0, 1.0)
	var fade := smoothstep(hold_fraction, 1.0, age)
	view.modulate.a = opacity * (1.0 - fade)
