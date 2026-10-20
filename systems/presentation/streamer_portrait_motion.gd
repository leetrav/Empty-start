class_name StreamerPortraitMotion
extends Control

signal shot_motion_started
signal shot_motion_finished

# PA-23-FIX: 停用循环待机漂浮、呼吸缩放和旋转，保持角色脚底稳定。
@export var body_pivot: Vector2 = Vector2(0.5, 0.65)
@export var shot_direction: Vector2 = Vector2.RIGHT
@export var shot_distance: float = 9.0
@export var shot_compression: float = 0.06
@export var recoil_count: int = 2
@export var recovery_seconds: float = 0.18

var idle_strength: float = 1.0
var _idle_layer: Control
var _shot_tween: Tween


# 在原立绘槽中插入事件层与待机层；外部事件继续作用于原槽或立绘本体。
func attach_portrait(portrait: TextureRect) -> void:
	var slot: Node = portrait.get_parent()
	var original_index: int = portrait.get_index()
	name = portrait.name + "Motion"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(self)
	slot.move_child(self, original_index)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_idle_layer = Control.new()
	_idle_layer.name = "Idle"
	_idle_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_idle_layer)
	_idle_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.reparent(_idle_layer, false)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_update_pivots)
	_update_pivots()
	restart_idle()


# 接口供正式 HUD / Plan B 兼容；人物差异只由阶段贴图和演出维护。
func configure_character(_character_id: String) -> void:
	restart_idle()


# 静态待机。层级保留，PA-17 结局演出和射击 Tween 仍使用外层变换。
func restart_idle() -> void:
	if _idle_layer == null:
		return
	_idle_layer.position = Vector2.ZERO
	_idle_layer.scale = Vector2.ONE
	_idle_layer.rotation = 0.0


# 枢轴随槽尺寸更新，运动围绕角色躯干。
func _update_pivots() -> void:
	pivot_offset = size * body_pivot
	_idle_layer.pivot_offset = size * body_pivot


# 满蓄快照到达后播放一次；连续发射取消旧 Tween 并复位事件层。
func play_shot() -> void:
	reset_shot()
	shot_motion_started.emit()
	var forward: Vector2 = shot_direction.normalized() * shot_distance
	_shot_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shot_tween.tween_property(self, "position", forward, 0.055)
	_shot_tween.parallel().tween_property(self, "scale", Vector2(1.0 + shot_compression * 0.5, 1.0 - shot_compression), 0.055)
	for index: int in range(maxi(recoil_count, 1)):
		var recoil: Vector2 = -forward * (0.45 / float(index + 1))
		_shot_tween.tween_property(self, "position", recoil, 0.045)
		_shot_tween.parallel().tween_property(self, "scale", Vector2(0.98, 1.02), 0.045)
		_shot_tween.tween_property(self, "position", forward * (0.15 / float(index + 1)), 0.035)
	_shot_tween.tween_property(self, "position", Vector2.ZERO, maxf(recovery_seconds, 0.01))
	_shot_tween.parallel().tween_property(self, "scale", Vector2.ONE, maxf(recovery_seconds, 0.01))
	_shot_tween.tween_callback(shot_motion_finished.emit)


# 重开或中断复位射击层；待机保持静止。
func reset_shot() -> void:
	if _shot_tween != null:
		_shot_tween.kill()
	position = Vector2.ZERO
	scale = Vector2.ONE
	rotation = 0.0


# 兼容旧调用，但不再驱动循环呼吸变换。
func set_idle_strength(value: float, _seconds: float = 0.15) -> void:
	idle_strength = clampf(value, 0.0, 1.0)

