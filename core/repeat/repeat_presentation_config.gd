extends Resource

# 分阶段可编辑表现；仅影响排期、可读性和寿命，原句身份及奖励规则保持原值。
## 0 保留生产调用方从 06 表与 Tier 解析的寿命；正值仅用于明确批准的表现覆盖。
@export var normal_lifetime_seconds: float = 0.0
@export var contradiction_lifetime_seconds: float = 0.7
@export var terminal_lifetime_seconds: float = 3.2
@export_range(0.0, 1.0) var normal_opacity: float = 0.85
@export_range(0.0, 1.0) var contradiction_opacity: float = 1.0
@export_range(0.0, 1.0) var terminal_opacity: float = 1.0
@export_range(0.0, 0.95) var normal_hold_fraction: float = 0.55
@export_range(0.0, 0.95) var contradiction_hold_fraction: float = 0.65
@export_range(0.0, 0.95) var terminal_hold_fraction: float = 0.8


# B 在成功生成后组合原生 Node，C 的 BarrageView/运动/命中实现保持单一来源。
func attach_to_view(view: BarrageView, phase: StringName) -> void:
	var driver := preload("res://core/repeat/repeat_presentation_driver.gd").new()
	driver.opacity = get(str(phase) + "_opacity")
	driver.hold_fraction = get(str(phase) + "_hold_fraction")
	view.add_child(driver)
