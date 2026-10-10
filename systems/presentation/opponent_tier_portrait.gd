class_name OpponentTierPortrait
extends Control

const TierFx = preload("res://systems/presentation/opponent_tier_fx.gd")

signal flip_finished(tier: int)

@export var flip_seconds: float = 0.32
@export_range(0.02, 0.5) var narrow_scale: float = 0.08
@export var rebound_scale: float = 1.07

var current_tier: int = 0
var fx: OpponentTierFx
var _portrait: TextureRect
var _idle: Texture2D
var _tier_01: Texture2D
var _tier_02: Texture2D
var _tier_03: Texture2D
var _flip_tween: Tween
var _shudder_tween: Tween
var _pending_texture: Texture2D


# 插入 PA-14 的 Idle 层内部，让汗滴、切图与现有呼吸动作共同移动。
func attach_portrait(portrait: TextureRect) -> void:
	var slot: Control = portrait.get_parent() as Control
	var index: int = portrait.get_index()
	name = "OpponentTierPortrait"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(self)
	slot.move_child(self, index)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait = portrait
	portrait.reparent(self, false)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.pivot_offset = portrait.size * 0.5
	fx = TierFx.new()
	fx.name = "TierFx"
	add_child(fx)
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_refresh_pivot)
	_refresh_pivot()


# 纹理由关卡/集成方显式提供；缺图时保留 idle 占位，不猜测文件名。
func configure_textures(idle: Texture2D, tier_01: Texture2D, tier_02: Texture2D, tier_03: Texture2D) -> void:
	_idle = idle
	_tier_01 = tier_01
	_tier_02 = tier_02
	_tier_03 = tier_03
	reset_for_tier(current_tier)


func show_tier(tier: int) -> void:
	var target_tier: int = clampi(tier, 0, 6)
	var target: Texture2D = _texture_for_tier(target_tier)
	if target_tier == current_tier and _flip_tween == null:
		return
	current_tier = target_tier
	fx.set_sweat(target_tier == 2)
	if _flip_tween != null:
		_flip_tween.kill()
		_flip_tween = null
	_portrait.scale = Vector2.ONE
	if _portrait.texture == target or _portrait.texture == null or target == null:
		_portrait.texture = target
		if target_tier == 1 or target_tier == 2:
			_play_shudder()
		return
	_pending_texture = target
	var half: float = maxf(flip_seconds, 0.08) * 0.5
	_flip_tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	_flip_tween.tween_method(_set_horizontal_scale, 1.0, narrow_scale, half).set_ease(Tween.EASE_IN)
	_flip_tween.tween_callback(_swap_at_edge)
	_flip_tween.tween_method(_set_horizontal_scale, narrow_scale, rebound_scale, half * 0.72).set_ease(Tween.EASE_OUT)
	_flip_tween.tween_method(_set_horizontal_scale, rebound_scale, 1.0, half * 0.28).set_ease(Tween.EASE_OUT)
	_flip_tween.tween_callback(_finish_flip)


# Paradox 沿用 T5，重开/断线取消残留动画。
func reset_for_tier(tier: int = 0) -> void:
	if _flip_tween != null:
		_flip_tween.kill()
		_flip_tween = null
	if _shudder_tween != null:
		_shudder_tween.kill()
		_shudder_tween = null
	position = Vector2.ZERO
	current_tier = clampi(tier, 0, 6)
	_portrait.scale = Vector2.ONE
	_portrait.texture = _texture_for_tier(current_tier)
	fx.reset_fx()
	fx.set_sweat(current_tier == 2)


func _texture_for_tier(tier: int) -> Texture2D:
	match tier:
		3:
			return _tier_01 if _tier_01 != null else _idle
		4:
			return _tier_02 if _tier_02 != null else _idle
		5, 6:
			return _tier_03 if _tier_03 != null else _idle
		_:
			return _idle


func _set_horizontal_scale(value: float) -> void:
	_portrait.scale = Vector2(value, 1.0)


func _play_shudder() -> void:
	if _shudder_tween != null:
		_shudder_tween.kill()
	position = Vector2.ZERO
	_shudder_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_shudder_tween.tween_property(self, "position", Vector2(5.0, -2.0), 0.045)
	_shudder_tween.tween_property(self, "position", Vector2(-3.0, 1.0), 0.055)
	_shudder_tween.tween_property(self, "position", Vector2.ZERO, 0.07)


func _swap_at_edge() -> void:
	_portrait.texture = _pending_texture
	fx.play_impact()


func _finish_flip() -> void:
	_flip_tween = null
	flip_finished.emit(current_tier)


func _refresh_pivot() -> void:
	if _portrait != null:
		_portrait.pivot_offset = size * 0.5
