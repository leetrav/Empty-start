## 普通战斗界面只读取场景组合方提供的状态，并按共享舞台尺寸排版。
extends Control

@export var stage_layout_profile: StageLayoutProfile

@onready var _player_area: Control = $PlayerStreamerArea
@onready var _battle_area: Control = $BattleArea
@onready var _opponent_area: Control = $OpponentStreamerArea
@onready var _barrage_area: BarrageArea = %BarrageArea
@onready var _aim_reticle: AimReticle = %AimReticle
@onready var _pk_bar_area: Control = $BattleArea/PKBar
@onready var _charge_feedback: Control = $BattleArea/ChargeFeedback
@onready var _battle_state: Label = $BattleArea/BattleStateFeedback
@onready var _player_name: Label = $PlayerStreamerArea/PlayerName
@onready var _opponent_name: Label = $OpponentStreamerArea/OpponentName
@onready var _player_pk_label: Label = $BattleArea/PKBar/PlayerPK
@onready var _opponent_pk_label: Label = $BattleArea/PKBar/OpponentPK
@onready var _pk_progress: ProgressBar = $BattleArea/PKBar/PlayerShare
@onready var _tier_label: Label = $BattleArea/PKBar/Tier
@onready var _tier_feedback: Label = $OpponentStreamerArea/TierFeedback/TierValue
@onready var _charge_label: Label = $BattleArea/ChargeFeedback/ChargeState
@onready var _charge_progress: ProgressBar = $BattleArea/ChargeFeedback/ChargeProgress
@onready var _live_data_hud: Control = %LiveDataHud
@onready var _failure_overlay: Control = %FailureOverlay
@onready var _restart_button: Button = %RestartButton

const CHARGE_FEEDBACK_HEIGHT: float = 112.0


# 子场景已经初始化后修正嵌套布局，避免 BarrageArea 再应用一次全舞台锚点。
func _ready() -> void:
	_apply_stage_layout()
	var parent_control: Control = get_parent() as Control
	parent_control.resized.connect(_fit_parent_size)
	_fit_parent_size()
	reset_for_attempt()


# 所有主播区、中央区、PK 条和直播数据区域都读取共享的设计尺寸。
func _apply_stage_layout() -> void:
	if stage_layout_profile == null:
		push_error("SandboxBattleHud: 缺少 StageLayoutProfile。")
		return
	var base_size: Vector2 = Vector2(stage_layout_profile.base_resolution)
	if base_size.x <= 0.0 or base_size.y <= 0.0:
		push_error("SandboxBattleHud: 舞台基准分辨率必须大于零。")
		return
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	size = base_size
	_set_design_rect(_player_area, Rect2(Vector2.ZERO, Vector2(stage_layout_profile.player_streamer_area_size)))
	_set_design_rect(_battle_area, Rect2(stage_layout_profile.central_barrage_area_rect))
	var opponent_size: Vector2 = Vector2(stage_layout_profile.opponent_streamer_area_size)
	_set_design_rect(_opponent_area, Rect2(Vector2(base_size.x - opponent_size.x, 0.0), opponent_size))
	var pk_size: Vector2 = Vector2(stage_layout_profile.pk_bar_area_size)
	_set_design_rect(_pk_bar_area, Rect2(Vector2.ZERO, pk_size))
	var live_data_size: Vector2 = Vector2(stage_layout_profile.live_data_area_size)
	_set_design_rect(_live_data_hud, Rect2(Vector2(0.0, _player_area.size.y - live_data_size.y), live_data_size))
	_set_design_rect(_charge_feedback, Rect2(Vector2(0.0, _battle_area.size.y - CHARGE_FEEDBACK_HEIGHT), Vector2(_battle_area.size.x, CHARGE_FEEDBACK_HEIGHT)))
	# 顶部 PK 条和底部蓄力区预留在弹幕有效区之外，所有反馈控件均透传鼠标。
	_set_design_rect(_barrage_area, Rect2(Vector2(0.0, pk_size.y), Vector2(_battle_area.size.x, maxf(_battle_area.size.y - pk_size.y - CHARGE_FEEDBACK_HEIGHT, 0.0))))
	_barrage_area.mouse_filter = Control.MOUSE_FILTER_IGNORE


# 使用设计坐标统一缩放文字和容器，窗口变化时保持左右区和中央区的比例。
func _fit_parent_size() -> void:
	var parent_control: Control = get_parent() as Control
	if parent_control == null or size.x <= 0.0 or size.y <= 0.0:
		return
	scale = parent_control.size / size
	# 准心继承同一设计缩放，布局更新后通过其公开入口重新对齐当前鼠标。
	_aim_reticle.refresh_mouse_position()


# 静态布局只设显示矩形，不保存任何战斗状态。
func _set_design_rect(control: Control, design_rect: Rect2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = design_rect.position
	control.size = design_rect.size


# 主播名称由当前关资料提供，后续立绘可以替换占位节点。
func configure_streamers(player_name: String, opponent_name: String) -> void:
	_player_name.text = player_name
	_opponent_name.text = opponent_name


# PK 唯一值归 HitResolution，HUD 只将它映射为玩家占比和对手占比。
func refresh_pk(player_pk: float, current_tier: int) -> void:
	var player_share: float = clampf(player_pk, 0.0, 1.0)
	_pk_progress.value = player_share
	_player_pk_label.text = "玩家 PK %.1f%%" % (player_share * 100.0)
	_opponent_pk_label.text = "对手 %.1f%%" % ((1.0 - player_share) * 100.0)
	_tier_label.text = "Tier %d" % current_tier
	_tier_feedback.text = "Tier %d" % current_tier


# 蓄力与阶段归 CombatAttack，HUD 使用公开读取结果提供可释放、飞行和硬直反馈。
func refresh_attack(progress: float, phase: int) -> void:
	var charge_progress: float = clampf(progress, 0.0, 1.0)
	_charge_progress.value = charge_progress
	match phase:
		AttackChargeInput.AttackPhase.PROJECTILE_FLIGHT:
			_charge_label.text = "飞行中"
		AttackChargeInput.AttackPhase.RECOVERY:
			_charge_label.text = "硬直中"
		_:
			_charge_label.text = "蓄满 100% · 松开发射" if charge_progress >= 1.0 else "蓄力 %d%%" % roundi(charge_progress * 100.0)


# 普通战斗完成及下一阶段等待提示由 Sandbox 生命周期组合方决定。
func show_battle_state(message: String) -> void:
	_battle_state.text = message


# 失败只切换可见界面；停止输入、回拉和生成继续由各状态拥有者处理。
func show_failure() -> void:
	_failure_overlay.show()
	_restart_button.grab_focus()


# 重开仅复位界面提示，各系统的本场状态由 Sandbox 分别初始化。
func reset_for_attempt() -> void:
	_failure_overlay.hide()
	show_battle_state("瞄准弹幕，蓄满后松开左键")
	refresh_attack(0.0, AttackChargeInput.AttackPhase.READY)
