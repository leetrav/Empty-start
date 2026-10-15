## 普通战斗界面只读取组合方的状态；设计矩形保存于 Scene，运行时只整体缩放。
extends Control

signal failure_presentation_finished()

signal dialogue_sequence_completed(sequence_id: StringName, side: int)
signal tier_breakthrough_finished(previous_tier: int, current_tier: int, completed: bool)

const PortraitMotion = preload("res://systems/presentation/streamer_portrait_motion.gd")
const TierPortrait = preload("res://systems/presentation/opponent_tier_portrait.gd")
const PK_BAR_SKIN_SCENE: PackedScene = preload("res://systems/presentation/pk_bar_skin.tscn")
const DialogueQueueScript = preload("res://ui/streamer_bubble_dialogue/streamer_bubble_dialogue_queue.gd")
const StageArrow = preload("res://systems/presentation/stage_arrow_fx.gd")
const CrtConnection = preload("res://systems/presentation/crt_connection_fx.gd")
const HAMSTER_LIVE_BACKGROUND: Texture2D = preload("res://assets/environment/live/hamster/background.png")
const HAMSTER_LIVE_FOREGROUND: Texture2D = preload("res://assets/environment/live/hamster/foreground_desk.png")
const STREAMER_NAME_BASE_FONT_SIZE: int = 32
const STREAMER_NAME_MIN_FONT_SIZE: int = 20
const FAN_GROUP_NAME_BASE_FONT_SIZE: int = 22
const FAN_GROUP_NAME_MIN_FONT_SIZE: int = 16
const FAN_GROUP_NAME_PLACEHOLDER: String = "粉丝团"

@export_range(1, 8, 1) var max_visible_dialogue_bubbles_per_side: int = 3
# 策划可在 HUD Inspector 中配置 T0 对手匹配等待文案。
@export_multiline var t0_matching_status_text: String = "等待对手连线……"
# 震动幅度与时长可由 HUD Inspector 调整；0 可关闭该表现。
@export_range(0.0, 32.0, 0.5) var tier_down_shake_amplitude: float = 6.0
@export_range(0.0, 1.0, 0.01) var tier_down_shake_duration_seconds: float = 0.18

# 在 HUD 检查器集中保存视觉参数，创建运行时子节点时传入，不影响阶段规则。
@export_group("PA-11 箭头")
@export var pa11_arrow_color: Color = Color(1.0, 0.94, 0.76, 0.78)
@export var pa11_arrow_outline_color: Color = Color(0.09, 0.10, 0.17, 0.78)
@export_range(0.08, 0.55, 0.01) var pa11_arrow_size_ratio: float = 0.28
@export_range(0.002, 0.04, 0.001) var pa11_arrow_outline_ratio: float = 0.012
@export_range(0.01, 0.5, 0.01) var pa11_arrow_pop_seconds: float = 0.12
@export_range(0.01, 0.5, 0.01) var pa11_arrow_thrust_seconds: float = 0.08
@export_range(0.0, 0.15, 0.005) var pa11_arrow_thrust_ratio: float = 0.025
@export_range(0.0, 0.5, 0.01) var pa11_arrow_hold_seconds: float = 0.08
@export_range(0.01, 0.6, 0.01) var pa11_arrow_fade_seconds: float = 0.20
@export_range(0.0, 0.3, 0.01) var pa11_arrow_travel_ratio: float = 0.09
@export_group("PA-11 CRT")
@export var pa11_crt_blackout_color: Color = Color(0.018, 0.024, 0.045, 1.0)
@export var pa11_crt_beam_color: Color = Color(0.91, 0.98, 1.0, 1.0)
@export_range(0.02, 0.3, 0.01) var pa11_crt_line_seconds: float = 0.10
@export_range(0.05, 0.6, 0.01) var pa11_crt_unfold_seconds: float = 0.30
@export_range(0.02, 0.3, 0.01) var pa11_crt_flash_seconds: float = 0.11
@export_range(0.02, 0.4, 0.01) var pa11_crt_settle_seconds: float = 0.17
@export_range(0.0, 1.0, 0.01) var pa11_crt_scanline_opacity: float = 0.34
@export_range(0.0, 1.0, 0.01) var pa11_crt_noise_opacity: float = 0.28
@export_range(0.0, 1.0, 0.01) var pa11_crt_flash_opacity: float = 0.50
@export_range(0.05, 0.5, 0.01) var pa11_crt_impact_size_ratio: float = 0.28
@export var pa11_crt_impact_offset_ratio: Vector2 = Vector2(0.32, -0.32)
@export_range(0.0, 12.0, 0.5) var pa11_crt_horizontal_distortion_pixels: float = 3.0
@export_group("PA-18 战败")
@export var pa18_drop_direction: float = 1.0
@export_range(60.0, 600.0, 10.0) var pa18_drop_distance: float = 280.0
@export_range(0.0, 5.0, 0.1) var pa18_drop_rotations: float = 1.5
@export_range(0.1, 2.0, 0.01) var pa18_drop_seconds: float = 0.55
@export_range(0.1, 2.0, 0.01) var pa18_shutdown_seconds: float = 0.55
@export_range(0.0, 1.0, 0.01) var pa18_failure_ui_delay: float = 0.15
@export_group("")

var player_portrait_motion: StreamerPortraitMotion
var opponent_portrait_motion: StreamerPortraitMotion
var opponent_tier_portrait: OpponentTierPortrait
var _portrait_attack: AttackChargeInput
var _opponent_connected: bool = false
var _paradox_stage_active: bool = false
var _last_status_tier: int = -1
var _pk_bar_skin: PkBarSkin
var _actual_player_pk: float = 0.5
var _active_opponent_status_text: String = ""
var _dialogue_queue: Node
var _tier_breakthrough_active: bool = false
var _stage_arrow: StageArrowFx
var _player_crt: CrtConnectionFx
var _failure_presentation_active: bool = false
var _failure_delay_tween: Tween
var _crt_connection: CrtConnectionFx
var _tier_breakthrough_previous_tier: int = -1
var _tier_breakthrough_current_tier: int = -1
var _tier_down_shake_tween: Tween
var _tier_down_shake_origin: Vector2 = Vector2.ZERO
# 保留攻击状态供后续获批的正式反馈视图读取；Sandbox 继续通过原公开刷新入口提交。
var attack_progress: float = 0.0
var attack_phase: int = AttackChargeInput.AttackPhase.READY

@onready var _aim_reticle: AimReticle = %AimReticle
@onready var _battle_state: Label = %BattleStateFeedback
@onready var _player_name: Label = $PlayerStreamerArea/PlayerInfoArea/PlayerName
@onready var _opponent_name: Label = $OpponentStreamerArea/OpponentInfoArea/OpponentName
@onready var _player_fan_group_name: Label = $PlayerStreamerArea/PlayerInfoArea/PlayerFanGroupName
@onready var _opponent_fan_group_name: Label = $OpponentStreamerArea/OpponentInfoArea/OpponentFanGroupName
@onready var _player_portrait: TextureRect = $PlayerStreamerArea/PlayerPortraitPlaceholder/PlayerPortraitArt
@onready var _player_live_background: TextureRect = $PlayerStreamerArea/PlayerPortraitPlaceholder/PlayerLiveBackground
@onready var _player_live_foreground: TextureRect = $PlayerStreamerArea/PlayerPortraitPlaceholder/PlayerLiveForeground
@onready var _player_portrait_placeholder: Label = $PlayerStreamerArea/PlayerPortraitPlaceholder/PlaceholderLabel
@onready var _player_bubble_stack: StreamerBubbleStack = %PlayerBubbleStack
@onready var _opponent_portrait: TextureRect = $OpponentStreamerArea/OpponentPortraitPlaceholder/OpponentPortraitArt
@onready var _opponent_live_background: TextureRect = $OpponentStreamerArea/OpponentPortraitPlaceholder/OpponentLiveBackground
@onready var _opponent_portrait_placeholder: Label = $OpponentStreamerArea/OpponentPortraitPlaceholder/PlaceholderLabel
@onready var _opponent_bubble_stack: StreamerBubbleStack = %OpponentBubbleStack
@onready var _player_pk_label: Label = %PlayerPK
@onready var _opponent_pk_label: Label = $BattleArea/TopBattleStatus/PKBar/OpponentPK
@onready var _pk_progress: ProgressBar = %PlayerShare
@onready var _pk_hamster_ball: PKHamsterBallIndicator = $BattleArea/TopBattleStatus/PKBar/HamsterBallIndicator
@onready var _tier_label: Label = %Tier
@onready var _battle_area: Control = $BattleArea
@onready var _failure_overlay: Control = %FailureOverlay
@onready var _restart_button: Button = %RestartButton


# 保留 Scene 的全部设计矩形，只订阅窗口变化并初始化显示。
func _ready() -> void:
	player_portrait_motion = PortraitMotion.new()
	player_portrait_motion.attach_portrait(_player_portrait)
	opponent_portrait_motion = PortraitMotion.new()
	opponent_portrait_motion.configure_character("alien")
	opponent_portrait_motion.attach_portrait(_opponent_portrait)
	opponent_tier_portrait = TierPortrait.new()
	opponent_tier_portrait.attach_portrait(_opponent_portrait)
	_pk_bar_skin = PK_BAR_SKIN_SCENE.instantiate() as PkBarSkin
	_pk_bar_skin.name = "PkBarSkin"
	_pk_progress.add_child(_pk_bar_skin)
	_dialogue_queue = DialogueQueueScript.new()
	_dialogue_queue.name = "BubbleDialogueQueue"
	_dialogue_queue.call(
		"configure",
		max_visible_dialogue_bubbles_per_side,
		Callable(self, "show_dialogue_bubble"),
		Callable(self, "_clear_bubble_stack")
	)
	_dialogue_queue.connect("sequence_completed", Callable(self, "_on_dialogue_sequence_completed"))
	add_child(_dialogue_queue)
	_pk_hamster_ball.display_progress_changed.connect(_refresh_pk_percentage)
	_pk_hamster_ball.bind_track(_pk_progress)
	# PA-11 只创建局部视觉层，清屏、暂停与对白恢复继续由现有 Flow 负责。
	_stage_arrow = StageArrow.new() as StageArrowFx
	_stage_arrow.arrow_color = pa11_arrow_color
	_stage_arrow.outline_color = pa11_arrow_outline_color
	_stage_arrow.arrow_size_ratio = pa11_arrow_size_ratio
	_stage_arrow.outline_ratio = pa11_arrow_outline_ratio
	_stage_arrow.pop_seconds = pa11_arrow_pop_seconds
	_stage_arrow.thrust_seconds = pa11_arrow_thrust_seconds
	_stage_arrow.thrust_ratio = pa11_arrow_thrust_ratio
	_stage_arrow.hold_seconds = pa11_arrow_hold_seconds
	_stage_arrow.fade_seconds = pa11_arrow_fade_seconds
	_stage_arrow.travel_ratio = pa11_arrow_travel_ratio
	_stage_arrow.name = "StageArrowFx"
	_stage_arrow.z_index = 20
	var barrage_area: Control = %BarrageArea
	barrage_area.add_child(_stage_arrow)
	_stage_arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_arrow.animation_finished.connect(_on_stage_arrow_finished)
	_crt_connection = CrtConnection.new() as CrtConnectionFx
	_crt_connection.blackout_color = pa11_crt_blackout_color
	_crt_connection.beam_color = pa11_crt_beam_color
	_crt_connection.line_seconds = pa11_crt_line_seconds
	_crt_connection.unfold_seconds = pa11_crt_unfold_seconds
	_crt_connection.flash_seconds = pa11_crt_flash_seconds
	_crt_connection.settle_seconds = pa11_crt_settle_seconds
	_crt_connection.scanline_opacity = pa11_crt_scanline_opacity
	_crt_connection.noise_opacity = pa11_crt_noise_opacity
	_crt_connection.flash_opacity = pa11_crt_flash_opacity
	_crt_connection.impact_size_ratio = pa11_crt_impact_size_ratio
	_crt_connection.impact_offset_ratio = pa11_crt_impact_offset_ratio
	_crt_connection.horizontal_distortion_pixels = pa11_crt_horizontal_distortion_pixels
	_crt_connection.name = "CrtConnectionFx"
	_crt_connection.z_index = 20
	_opponent_live_background.get_parent().add_child(_crt_connection)
	_crt_connection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crt_connection.bind_video_layers([_opponent_live_background, _opponent_portrait])
	_crt_connection.connection_finished.connect(_finish_tier_breakthrough)
	# 左侧实例与右侧开机实例独立，收屏范围读取直播容器实际尺寸。
	_player_crt = CrtConnection.new() as CrtConnectionFx
	_player_crt.name = "PlayerCrtShutdownFx"
	_player_crt.blackout_color = pa11_crt_blackout_color
	_player_crt.beam_color = pa11_crt_beam_color
	_player_crt.z_index = 20
	_player_live_background.get_parent().add_child(_player_crt)
	_player_crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player_crt.bind_video_layers([_player_live_background, _player_portrait, _player_live_foreground])
	_pk_hamster_ball.failure_fall_finished.connect(_on_failure_ball_finished)
	_player_crt.shutdown_finished.connect(_on_player_shutdown_finished)
	var parent_control: Control = get_parent() as Control
	parent_control.resized.connect(_fit_parent_size)
	_fit_parent_size()
	reset_for_attempt()


# 使用设计坐标统一缩放文字和容器，窗口变化时保持左右区和中央区的比例。
func _fit_parent_size() -> void:
	var parent_control: Control = get_parent() as Control
	if parent_control == null or size.x <= 0.0 or size.y <= 0.0:
		return
	scale = parent_control.size / size
	# 准心继承同一设计缩放，布局更新后通过其公开入口重新对齐当前鼠标。
	_aim_reticle.refresh_mouse_position()


# 主播名称由当前关资料提供，后续立绘可以替换占位节点。
func configure_streamers(player_name: String, opponent_name: String) -> void:
	_player_name.text = player_name
	_opponent_name.text = opponent_name
	_fit_streamer_header_label(_player_name, STREAMER_NAME_BASE_FONT_SIZE, STREAMER_NAME_MIN_FONT_SIZE)
	_fit_streamer_header_label(_opponent_name, STREAMER_NAME_BASE_FONT_SIZE, STREAMER_NAME_MIN_FONT_SIZE)


# 从周目 SaveData 与当前关卡 Resource 收到真实团名；空值只影响显示占位。
func configure_fan_group_names(player_fan_group_name: String, opponent_fan_group_name: String) -> void:
	_player_fan_group_name.text = _format_fan_group_name(player_fan_group_name)
	_opponent_fan_group_name.text = _format_fan_group_name(opponent_fan_group_name)
	_fit_streamer_header_label(
		_player_fan_group_name, FAN_GROUP_NAME_BASE_FONT_SIZE, FAN_GROUP_NAME_MIN_FONT_SIZE
	)
	_fit_streamer_header_label(
		_opponent_fan_group_name, FAN_GROUP_NAME_BASE_FONT_SIZE, FAN_GROUP_NAME_MIN_FONT_SIZE
	)


# 固定包裹爱心，空数据使用短名称保持左右栏布局完整。
func _format_fan_group_name(fan_group_name: String) -> String:
	var trimmed_name: String = fan_group_name.strip_edges()
	if trimmed_name.is_empty():
		trimmed_name = FAN_GROUP_NAME_PLACEHOLDER
	return "❤%s❤" % trimmed_name


# 名字按当前可用宽度缩小字号；极长文本由 Label 以省略号收尾，避免压住另一栏。
func _fit_streamer_header_label(label: Label, base_font_size: int, min_font_size: int) -> void:
	var font: Font = label.get_theme_font("font")
	if font == null or label.size.x <= 0.0:
		return
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS_FORCE
	var fitted_font_size: int = min_font_size
	for candidate_size: int in range(base_font_size, min_font_size - 1, -1):
		var text_width: float = font.get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, candidate_size
		).x
		if text_width <= label.size.x:
			fitted_font_size = candidate_size
			break
	label.add_theme_font_size_override("font_size", fitted_font_size)


# 顶栏徽章槽已改为名称文字；纹理参数保留旧调用兼容，资源归 LD-15 评论消费者读取。
func configure_streamer_assets(
	player_portrait: Texture2D,
	player_live_background: Texture2D,
	_player_fan_badge: Texture2D,
	opponent_portrait: Texture2D,
	opponent_live_background: Texture2D,
	_opponent_fan_badge: Texture2D
) -> void:
	# 保留既有调用签名兼容；评论粉丝牌继续从 PresentationAssetConfig / LevelProfile 读取。
	_set_texture_rect(_player_live_background, player_live_background, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	# 仓鼠直播背景的透明桌面位于立绘之前景；替换背景时不混入不匹配的桌面。
	_set_texture_rect(_player_live_foreground, HAMSTER_LIVE_FOREGROUND if player_live_background == HAMSTER_LIVE_BACKGROUND else null, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	_set_texture_rect(_player_portrait, player_portrait, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	_player_portrait_placeholder.visible = player_portrait == null

	_set_texture_rect(_opponent_live_background, opponent_live_background, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	_set_texture_rect(_opponent_portrait, opponent_portrait, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	opponent_tier_portrait.configure_textures(opponent_portrait, null, null, null)
	_opponent_portrait_placeholder.visible = opponent_portrait == null
	set_opponent_portrait_connected(_opponent_connected)


# LC-10 接入正式 23 表后，可将当前关的四张阶段图一次性交给本入口。
func configure_opponent_tier_textures(idle: Texture2D, tier_01: Texture2D, tier_02: Texture2D, tier_03: Texture2D) -> void:
	opponent_tier_portrait.configure_textures(idle, tier_01, tier_02, tier_03)
	set_opponent_portrait_connected(_opponent_connected)


# 集成方显式绑定正式发射通知；重复绑定不会叠加回调，null 可解除旧来源。
func bind_portrait_attack(attack: AttackChargeInput) -> void:
	if is_instance_valid(_portrait_attack) and _portrait_attack.shot_snapshot_created.is_connected(play_player_shot):
		_portrait_attack.shot_snapshot_created.disconnect(play_player_shot)
	_portrait_attack = attack
	if is_instance_valid(_portrait_attack):
		_portrait_attack.shot_snapshot_created.connect(play_player_shot)


# 此入口仅接收正式满蓄快照；命中、飞行到达和蓄力刷新均不触发射击动作。
func play_player_shot(snapshot: AttackTargetSnapshot) -> void:
	if snapshot == null:
		return
	# 同一份正式发射快照驱动立绘与 PA-08 准星短闪；立绘不可见也能播放准星反馈。
	_aim_reticle.play_shot_feedback()
	if _player_portrait.is_visible_in_tree():
		player_portrait_motion.play_shot()


# T0 隐藏立绘，阶段换图仍复用当前待机容器；背景与其他演出由集成方管理。
func set_opponent_portrait_connected(connected: bool) -> void:
	# 连线演出期间先关闭对白侧；CRT 展开时仅显露画面，稳定后由现有完成入口启用对白。
	if _tier_breakthrough_active and _tier_breakthrough_previous_tier == 0:
		connected = false
	_opponent_connected = connected
	if _dialogue_queue != null:
		_dialogue_queue.call("set_side_enabled", BubbleDialogueEntry.SpeakerSide.OPPONENT, connected)
	_opponent_portrait.visible = connected and _opponent_portrait.texture != null
	opponent_tier_portrait.visible = connected and _opponent_portrait.texture != null
	_opponent_portrait_placeholder.visible = connected and _opponent_portrait.texture == null
	if _crt_connection != null and not _tier_breakthrough_active:
		if connected:
			_crt_connection.reset_connected()
		else:
			_crt_connection.reset_disconnected()


# 当前关角色 ID 由集成方传入；后续换阶段 PNG 无需重建动画层。
func configure_portrait_character(opponent_character_id: String) -> void:
	opponent_portrait_motion.configure_character(opponent_character_id)


# 组合方提交 SD-01 条目；HUD 只按发言侧转发给对应立绘区，不判断触发规则。
func show_dialogue_bubble(entry: BubbleDialogueEntry) -> StreamerBubbleView:
	if entry == null or entry.text.strip_edges().is_empty():
		return null
	match entry.side:
		BubbleDialogueEntry.SpeakerSide.PLAYER:
			return _player_bubble_stack.show_bubble(entry)
		BubbleDialogueEntry.SpeakerSide.OPPONENT:
			return _opponent_bubble_stack.show_bubble(entry)
	return null


func enqueue_dialogue_bubble(entry: BubbleDialogueEntry) -> bool:
	return bool(_dialogue_queue.call("enqueue_entry", entry)) if _dialogue_queue != null else false


func enqueue_dialogue_sequence(
	entries: Array[BubbleDialogueEntry], sequence_id: StringName = &""
) -> StringName:
	if _dialogue_queue == null:
		return &""
	return StringName(_dialogue_queue.call("enqueue_sequence", entries, sequence_id))


func clear_dialogue_bubbles(side: int = -1) -> void:
	if _dialogue_queue != null:
		_dialogue_queue.call("clear_side", side)
	else:
		_clear_bubble_stack(side)


func _clear_bubble_stack(side: int) -> void:
	if side == -1 or side == BubbleDialogueEntry.SpeakerSide.PLAYER:
		_player_bubble_stack.clear_bubbles()
	if side == -1 or side == BubbleDialogueEntry.SpeakerSide.OPPONENT:
		_opponent_bubble_stack.clear_bubbles()


func _on_dialogue_sequence_completed(sequence_id: StringName, side: int) -> void:
	dialogue_sequence_completed.emit(sequence_id, side)


# TextureRect 沿用当前设计框尺寸，背景裁切铺满，立绘和粉丝牌保留完整比例。
func _set_texture_rect(texture_rect: TextureRect, texture: Texture2D, stretch_mode: int) -> void:
	texture_rect.texture = texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = stretch_mode
	texture_rect.visible = texture != null


# PK 唯一值归 HitResolution，HUD 只将它映射为玩家占比和对手占比。
func refresh_pk(player_pk: float, current_tier: int) -> void:
	# 匹配提示、对手立绘和对白侧只在真实 Tier 变化时切换；PK 连续刷新不重复清理离线对白。
	if current_tier != _last_status_tier:
		var previous_tier: int = _last_status_tier
		var opponent_was_connected: bool = _opponent_connected
		_last_status_tier = current_tier
		opponent_tier_portrait.show_tier(current_tier)
		if previous_tier >= 0 and current_tier < previous_tier:
			cancel_tier_breakthrough()
			_stage_arrow.play(-1)
			_play_tier_down_shake()
		if opponent_was_connected and current_tier == 0:
			# 对手刚离线时优先显示重新匹配状态，避免旧战斗提示遮住离线事实。
			_show_opponent_status(t0_matching_status_text)
		else:
			_refresh_opponent_status(current_tier)
		# T0 对手离线并隐藏立绘；进入 T1 后显示本关配置的待机图，降档与回升复用同一入口。
		set_opponent_portrait_connected(current_tier > 0)
	var player_share: float = clampf(player_pk, 0.0, 1.0)
	_actual_player_pk = player_share
	if _pk_bar_skin != null:
		_pk_bar_skin.set_display_state(player_share, current_tier, _paradox_stage_active)
	# PA-13 统一驱动填充、球心和百分比；底板选择继续读取真实 PK。
	_pk_hamster_ball.set_player_pk(player_share)
	_refresh_stage_label(current_tier)


# 百分比只消费同一显示进度，不把动画插值回写战斗事实。
func _refresh_pk_percentage(player_share: float) -> void:
	_player_pk_label.text = "玩家 PK %.1f%%" % (player_share * 100.0)
	_opponent_pk_label.text = "对手 %.1f%%" % ((1.0 - player_share) * 100.0)


# 只消费 CombatStage 的实际档位变化通知；PK 百分比回落本身不会触发降档表情。
func on_tier_changed(current_tier: int, player_pk: float) -> void:
	_pk_hamster_ball.set_player_pk(player_pk)
	_pk_hamster_ball.on_tier_changed(current_tier)


# 只移动战斗区的显示父节点；弹幕逻辑、运动和寿命继续正常推进。
func _play_tier_down_shake() -> void:
	_cancel_tier_down_shake()
	if tier_down_shake_amplitude <= 0.0 or tier_down_shake_duration_seconds <= 0.0:
		return
	_tier_down_shake_origin = _battle_area.position
	var directions: Array[Vector2] = [
		Vector2(-1.0, -0.35),
		Vector2(1.0, 0.35),
		Vector2(-0.65, 0.25),
		Vector2(0.45, -0.2),
		Vector2(-0.2, 0.0),
		Vector2.ZERO,
	]
	var step_seconds: float = tier_down_shake_duration_seconds / directions.size()
	_tier_down_shake_tween = create_tween()
	_tier_down_shake_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for direction: Vector2 in directions:
		_tier_down_shake_tween.tween_property(
			_battle_area,
			"position",
			_tier_down_shake_origin + direction * tier_down_shake_amplitude,
			step_seconds
		)
	var active_tween: Tween = _tier_down_shake_tween
	active_tween.finished.connect(_finish_tier_down_shake.bind(active_tween))


# 震动结束后回到原布局位置。
func _finish_tier_down_shake(active_tween: Tween) -> void:
	if active_tween != _tier_down_shake_tween:
		return
	_tier_down_shake_tween = null
	_battle_area.position = _tier_down_shake_origin


# 重开或被新降档覆盖时取消旧 Tween，并恢复战斗区原位。
func _cancel_tier_down_shake() -> void:
	if _tier_down_shake_tween == null:
		return
	var active_tween: Tween = _tier_down_shake_tween
	_tier_down_shake_tween = null
	active_tween.kill()
	_battle_area.position = _tier_down_shake_origin


# 仅切换 HUD 阶段文案；普通 CombatStage Tier 与 PK 仍由战斗流程持有。
func set_paradox_stage_active(active: bool, current_tier: int) -> void:
	_paradox_stage_active = active
	if _pk_bar_skin != null:
		_pk_bar_skin.set_display_state(_actual_player_pk, current_tier, active)
	_refresh_stage_label(current_tier)


func _refresh_stage_label(current_tier: int) -> void:
	# 文案覆盖只属于视图，普通 Tier 仍从调用方即时读取。
	_tier_label.text = "T6 / Paradox" if _paradox_stage_active else "Tier %d" % current_tier


# 已有 CS-14 清屏完成入口调用本方法；这里只负责箭头和首次连线 CRT 的顺序。
func play_tier_breakthrough(previous_tier: int, current_tier: int) -> bool:
	if previous_tier < 0 or current_tier <= previous_tier or not is_node_ready():
		return false
	cancel_tier_breakthrough()
	_tier_breakthrough_previous_tier = previous_tier
	_tier_breakthrough_current_tier = current_tier
	_tier_breakthrough_active = true
	if previous_tier == 0:
		_crt_connection.reset_disconnected()
	_stage_arrow.play(1)
	return true


# 重开或降档打断演出时清理视觉层；不恢复输入、回拉或生成。
func is_stage_transition_playing() -> bool:
	return _tier_breakthrough_active or (_stage_arrow != null and _stage_arrow.is_playing()) or (_crt_connection != null and _crt_connection.is_connecting())


# 战斗生命周期已停止时，由组合方撤销尚未结束的表现。
func cancel_tier_breakthrough() -> void:
	if _stage_arrow != null:
		_stage_arrow.reset_effect()
	if _crt_connection != null and _crt_connection.is_connecting():
		_crt_connection.reset_disconnected()
	if not _tier_breakthrough_active:
		return
	var previous_tier: int = _tier_breakthrough_previous_tier
	var current_tier: int = _tier_breakthrough_current_tier
	_tier_breakthrough_active = false
	tier_breakthrough_finished.emit(previous_tier, current_tier, false)


# 上箭头结束后，首次连线继续 CRT；普通升档直接交回现有流程。
func _on_stage_arrow_finished(direction: int) -> void:
	if direction < 0 or not _tier_breakthrough_active:
		return
	if _tier_breakthrough_previous_tier == 0:
		_opponent_portrait.visible = _opponent_portrait.texture != null
		opponent_tier_portrait.visible = _opponent_portrait.texture != null
		_opponent_portrait_placeholder.visible = _opponent_portrait.texture == null
		_crt_connection.play_connection()
	else:
		_finish_tier_breakthrough()


# 视觉结束只发布既有完成信号，由 Sandbox / Flow 决定对白与战斗恢复。
func _finish_tier_breakthrough() -> void:
	if not _tier_breakthrough_active:
		return
	var previous_tier: int = _tier_breakthrough_previous_tier
	var current_tier: int = _tier_breakthrough_current_tier
	_tier_breakthrough_active = false
	tier_breakthrough_finished.emit(previous_tier, current_tier, true)


# 蓄力与阶段归 CombatAttack；HUD 保留最新数值，供后续获批的美术反馈接入。
func refresh_attack(progress: float, phase: int) -> void:
	attack_progress = clampf(progress, 0.0, 1.0)
	attack_phase = phase
	# PA-08 使用现有 CombatAttack 的唯一蓄力状态驱动环形准星。
	var holding: bool = is_instance_valid(_portrait_attack) and _portrait_attack.is_charge_held()
	var full: bool = is_instance_valid(_portrait_attack) and _portrait_attack.is_fully_charged()
	_aim_reticle.set_charge_visual_state(attack_progress, holding, full)


# 外部战斗状态统一走此入口，并结束 HUD 对匹配提示的临时所有权。
func show_battle_state(message: String) -> void:
	# 顶部状态区只有两行；消息内部换行统一显示为分隔符，保持反馈完整可读。
	_active_opponent_status_text = ""
	_battle_state.text = message.replace("\n", " · ")


# Tier 连接状态只在旧状态仍可见时切换，保护战斗流程刚发出的实时提示。
func _refresh_opponent_status(current_tier: int) -> void:
	if _active_opponent_status_text.is_empty() or _battle_state.text != _active_opponent_status_text:
		return
	_show_opponent_status(t0_matching_status_text if current_tier == 0 else "对手已连线")


# 将 HUD 自己持有的匹配提示标记为可随 Tier 更新的状态。
func _show_opponent_status(message: String) -> void:
	show_battle_state(message)
	_active_opponent_status_text = _battle_state.text


# 失败只切换可见界面；停止输入、回拉和生成继续由各状态拥有者处理。
func show_failure() -> void:
	cancel_tier_breakthrough()
	# 先清理旧开场对白；失败事件的新对白随后由既有消费者提交。
	clear_dialogue_bubbles()
	_failure_overlay.show()
	_restart_button.grab_focus()


# 重开复位本场 HUD 提示并读取当前 T0 等待文案，各系统状态仍由所属对象初始化。
func reset_for_attempt(current_tier: int = 0) -> void:
	_failure_presentation_active = false
	if _failure_delay_tween != null:
		_failure_delay_tween.kill()
	if _player_crt != null:
		_player_crt.reset_connected()
	cancel_tier_breakthrough()
	_cancel_tier_down_shake()
	# 重开/失败后的下一场从待机准星开始，避免保留上一发充能高亮。
	_aim_reticle.reset_visual_state()
	player_portrait_motion.reset_shot()
	opponent_portrait_motion.reset_shot()
	clear_dialogue_bubbles()
	player_portrait_motion.set_idle_strength(1.0)
	opponent_portrait_motion.set_idle_strength(1.0)
	opponent_tier_portrait.reset_for_tier()
	set_opponent_portrait_connected(false)
	_pk_hamster_ball.reset_for_attempt(current_tier, _actual_player_pk)
	if _pk_bar_skin != null:
		_pk_bar_skin.reset_for_attempt(_actual_player_pk, 0, false)
	set_paradox_stage_active(false, 0)
	_last_status_tier = 0
	_failure_overlay.hide()
	_show_opponent_status(t0_matching_status_text)
	refresh_attack(0.0, AttackChargeInput.AttackPhase.READY)


# 正式失败事实由 Sandbox 转入；只延后画面，不重新控制战斗数值或输入。
func play_failure_presentation() -> void:
	if _failure_presentation_active or _failure_overlay.visible:
		return
	if _actual_player_pk > 0.0:
		failure_presentation_finished.emit()
		return
	_failure_presentation_active = true
	cancel_tier_breakthrough()
	_cancel_tier_down_shake()
	clear_dialogue_bubbles()
	player_portrait_motion.reset_shot()
	player_portrait_motion.set_idle_strength(0.0)
	# 失败归零会刷新到 T0，断流演出中仍保留最后已配置的对手直播。
	set_opponent_portrait_connected(true)
	_pk_hamster_ball.play_failure_fall(pa18_drop_direction, pa18_drop_distance, pa18_drop_rotations, pa18_drop_seconds)


func _on_failure_ball_finished() -> void:
	if not _failure_presentation_active:
		return
	_player_crt.shutdown_seconds = pa18_shutdown_seconds
	_player_crt.play_shutdown()


func _on_player_shutdown_finished() -> void:
	if not _failure_presentation_active:
		return
	_failure_delay_tween = create_tween()
	_failure_delay_tween.tween_interval(pa18_failure_ui_delay)
	_failure_delay_tween.tween_callback(_finish_failure_presentation)


func _finish_failure_presentation() -> void:
	if _failure_presentation_active:
		failure_presentation_finished.emit()
