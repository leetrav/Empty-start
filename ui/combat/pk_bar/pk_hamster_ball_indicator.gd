class_name PKHamsterBallIndicator
extends Control

signal display_progress_changed(player_share: float)

const SMILING_TEXTURE: Texture2D = preload("res://assets/ui/combat/pk_bar/pk_indicator_01.png")
const PANIC_TEXTURE: Texture2D = preload("res://assets/ui/combat/pk_bar/pk_indicator_02.png")
const BURST_TEXTURE: Texture2D = preload("res://assets/ui/combat/pk_bar/pk_indicator_03.png")

@export_range(24.0, 64.0, 1.0) var indicator_size: float = 40.0
@export_range(0.05, 0.3, 0.01) var progress_move_seconds: float = 0.16
@export_range(0.0, 0.08, 0.001) var roll_radians_per_pixel: float = 0.012
@export_range(-32.0, 32.0, 1.0) var track_vertical_offset: float = 0.0
@export_range(8.0, 32.0, 1.0) var tier_up_jump_height: float = 19.0
@export_range(8.0, 32.0, 1.0) var tier_down_jump_height: float = 15.0
@export_range(0.0, 0.3, 0.01) var tier_down_shake_radians: float = 0.12
@export_range(0.1, 0.5, 0.01) var tier_action_seconds: float = 0.32

@onready var _ball: TextureRect = $Ball

var _track: ProgressBar
var _panic_round_texture: Texture2D
var _burst_round_texture: Texture2D
var _target_center_x: float = 0.0
var _track_center_y: float = 0.0
var _player_pk: float = 0.5
var _display_pk: float = 0.5
var _move_start_pk: float = 0.5
var _move_elapsed: float = 0.0
var _moving: bool = false
var _last_tier: int = 0
var _roll_rotation: float = 0.0
var _action_rotation: float = 0.0
var _jump_offset: float = 0.0
var _shake_offset: float = 0.0
var _action_tween: Tween


func _ready() -> void:
	# Sprite 只在 PK 条范围内移动；容器保持不裁切，让球心位于轨道端点时仍完整可见。
	clip_contents = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panic_round_texture = _make_panic_texture(PANIC_TEXTURE, SMILING_TEXTURE)
	_burst_round_texture = _make_panic_texture(BURST_TEXTURE, SMILING_TEXTURE)
	size = Vector2.ONE * indicator_size
	_ball.position = Vector2.ZERO
	_ball.size = Vector2.ONE * indicator_size
	_ball.pivot_offset = _ball.size * 0.5
	_ball.texture = SMILING_TEXTURE
	_ball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ball.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ball.mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind_track(track: ProgressBar) -> void:
	# 轨道引用由 HUD 明确注入，位置映射始终读取同一个 ProgressBar 的实际矩形。
	if _track != null and _track.resized.is_connected(_refresh_track_layout):
		_track.resized.disconnect(_refresh_track_layout)
	_track = track
	if _track == null:
		return
	_track.resized.connect(_refresh_track_layout)
	_refresh_track_layout()


func set_player_pk(player_pk: float) -> void:
	# 连续更新只改目标，不重启动计时，避免每帧回拉让动画一直拖尾。
	var next_pk: float = clampf(player_pk, 0.0, 1.0)
	if is_equal_approx(next_pk, _player_pk):
		return
	_player_pk = next_pk
	if not _moving:
		_move_start_pk = _display_pk
		_move_elapsed = 0.0
		_moving = true


func reset_for_attempt(current_tier: int, player_pk: float = 0.5) -> void:
	# 新尝试取消残留动作并回到笑脸；保留当前 PK 映射，避免等待下一次数值刷新。
	if _action_tween != null and _action_tween.is_running():
		_action_tween.kill()
	_last_tier = current_tier
	_ball.texture = SMILING_TEXTURE
	_jump_offset = 0.0
	_shake_offset = 0.0
	_roll_rotation = 0.0
	_action_rotation = 0.0
	_ball.scale = Vector2.ONE
	_apply_ball_transform()
	_moving = false
	_player_pk = clampf(player_pk, 0.0, 1.0)
	_display_pk = _player_pk
	_refresh_target_position(true)


func on_tier_changed(current_tier: int) -> void:
	# 只在 CombatStage 明确通知 Tier 变化时表演；PK 回拉本身不会触发惊慌表情。
	if current_tier == _last_tier:
		return
	var tier_increased: bool = current_tier > _last_tier
	_last_tier = current_tier
	_play_tier_action(tier_increased)


func _process(delta: float) -> void:
	if not _moving or not is_instance_valid(_track):
		return
	_move_elapsed += delta
	var progress: float = clampf(_move_elapsed / maxf(progress_move_seconds, 0.001), 0.0, 1.0)
	_display_pk = lerpf(_move_start_pk, _player_pk, sin(progress * PI * 0.5))
	if progress >= 1.0:
		_display_pk = _player_pk
		_moving = false
	# 每个移动帧统一应用填充、球心和滚动角，完成后才通知百分比显示。
	_refresh_target_position(true, true)


func _refresh_track_layout() -> void:
	if not is_instance_valid(_track):
		return
	_refresh_target_position(true)


func _refresh_target_position(snap: bool = false, update_roll: bool = false) -> void:
	if not is_instance_valid(_track):
		return
	var previous_x: float = position.x
	# 填充与球共用显示值；读取 Range 实际值，消除 step 量化造成的微小错位。
	_track.value = _display_pk
	_target_center_x = _track.position.x + _track.size.x * _track.value
	_track_center_y = _track.position.y + _track.size.y * 0.5 + track_vertical_offset
	position.y = _track_center_y - size.y * 0.5
	if snap:
		position.x = _target_center_x - size.x * 0.5
	# 布局重算和重开只定位；正常移动才按本帧实际位移累加滚动。
	if update_roll:
		_roll_rotation += (position.x - previous_x) * roll_radians_per_pixel
		_apply_ball_transform()
	display_progress_changed.emit(_track.value)


func _play_tier_action(tier_increased: bool) -> void:
	if _action_tween != null and _action_tween.is_running():
		_action_tween.kill()
	_jump_offset = 0.0
	_shake_offset = 0.0
	_action_rotation = 0.0
	_ball.scale = Vector2.ONE
	_ball.texture = _burst_round_texture if tier_increased else _panic_round_texture
	_apply_ball_transform()
	_action_tween = create_tween()
	if tier_increased:
		_play_tier_up_action()
	else:
		_play_tier_down_action()
	_action_tween.tween_callback(_finish_tier_action)


func _play_tier_up_action() -> void:
	# 升档用爆发表情短跳和轻微回弹，横向位置仍跟随共同显示进度。
	var rise_seconds: float = tier_action_seconds * 0.34
	_action_tween.tween_method(_set_jump_offset, 0.0, -tier_up_jump_height, rise_seconds)
	_action_tween.parallel().tween_property(_ball, "scale", Vector2.ONE * 1.12, rise_seconds)
	_action_tween.parallel().tween_method(_set_action_rotation, 0.0, 0.18, rise_seconds)
	_action_tween.tween_method(_set_jump_offset, -tier_up_jump_height, 2.0, tier_action_seconds * 0.36)
	_action_tween.parallel().tween_property(_ball, "scale", Vector2.ONE * 0.94, tier_action_seconds * 0.36)
	_action_tween.tween_method(_set_jump_offset, 2.0, 0.0, tier_action_seconds * 0.30)
	_action_tween.parallel().tween_property(_ball, "scale", Vector2.ONE, tier_action_seconds * 0.30)
	_action_tween.parallel().tween_method(_set_action_rotation, 0.18, 0.0, tier_action_seconds * 0.30)


func _play_tier_down_action() -> void:
	# 降档短暂惊慌并抖动跳起；数值降低但未降 Tier 时仍保持笑脸。
	var shake_step: float = tier_action_seconds * 0.075
	var rise_seconds: float = tier_action_seconds * 0.28
	_action_tween.tween_method(_set_shake_offset, 0.0, -tier_down_shake_radians, shake_step)
	_action_tween.parallel().tween_method(_set_jump_offset, 0.0, -tier_down_jump_height, rise_seconds)
	_action_tween.tween_method(_set_shake_offset, -tier_down_shake_radians, tier_down_shake_radians, shake_step)
	_action_tween.tween_method(_set_shake_offset, tier_down_shake_radians, -tier_down_shake_radians * 0.6, shake_step)
	_action_tween.tween_method(_set_shake_offset, -tier_down_shake_radians * 0.6, 0.0, shake_step)
	_action_tween.tween_method(_set_jump_offset, -tier_down_jump_height, 2.0, tier_action_seconds * 0.34)
	_action_tween.parallel().tween_property(_ball, "scale", Vector2.ONE * 0.94, tier_action_seconds * 0.34)
	_action_tween.tween_method(_set_jump_offset, 2.0, 0.0, tier_action_seconds * 0.38)
	_action_tween.parallel().tween_property(_ball, "scale", Vector2.ONE, tier_action_seconds * 0.38)


func _set_jump_offset(value: float) -> void:
	_jump_offset = value
	_apply_ball_transform()


func _set_shake_offset(value: float) -> void:
	_shake_offset = value
	_apply_ball_transform()


func _set_action_rotation(value: float) -> void:
	_action_rotation = value
	_apply_ball_transform()


func _apply_ball_transform() -> void:
	if not is_instance_valid(_ball):
		return
	# 震颤绕球心旋转，不改变真实进度横坐标。
	_ball.position = Vector2(0.0, _jump_offset)
	_ball.rotation = _roll_rotation + _action_rotation + _shake_offset


func _finish_tier_action() -> void:
	# 动效完成后回到轨道中心与笑脸，防止连续升降档留下局部偏移。
	_ball.texture = SMILING_TEXTURE
	_jump_offset = 0.0
	_shake_offset = 0.0
	_action_rotation = 0.0
	_ball.scale = Vector2.ONE
	_apply_ball_transform()


func _make_panic_texture(source: Texture2D, silhouette_source: Texture2D) -> Texture2D:
	# 特殊表情复用笑脸 PNG 的透明轮廓，避免旋转时露出方形底；不修改原始素材。
	var image: Image = _get_editable_texture_image(source)
	var silhouette: Image = _get_editable_texture_image(silhouette_source)
	if image == null or silhouette == null:
		push_error("PA-13: 仓鼠球表情图无法读取，特殊表情已回退为笑脸。")
		return SMILING_TEXTURE
	if image.get_size() != silhouette.get_size():
		push_error("PA-13: 仓鼠球表情图尺寸不一致，特殊表情已回退为笑脸。")
		return SMILING_TEXTURE

	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			pixel.a *= silhouette.get_pixel(x, y).a
			if pixel.a <= 0.001:
				pixel = Color.TRANSPARENT
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)


func _get_editable_texture_image(texture: Texture2D) -> Image:
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed() and image.decompress() != OK:
		return null
	return image
