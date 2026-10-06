## 普通战斗界面只读取组合方的状态；设计矩形保存于 Scene，运行时只整体缩放。
extends Control

@onready var _aim_reticle: AimReticle = %AimReticle
@onready var _battle_state: Label = %BattleStateFeedback
@onready var _player_name: Label = $PlayerStreamerArea/PlayerInfoArea/PlayerName
@onready var _opponent_name: Label = $OpponentStreamerArea/OpponentInfoArea/OpponentName
@onready var _player_pk_label: Label = %PlayerPK
@onready var _opponent_pk_label: Label = $BattleArea/TopBattleStatus/PKBar/OpponentPK
@onready var _pk_progress: ProgressBar = %PlayerShare
@onready var _tier_label: Label = %Tier
@onready var _charge_label: Label = $BattleArea/ChargeFeedback/ChargeState
@onready var _charge_progress: ProgressBar = %ChargeProgress
@onready var _failure_overlay: Control = %FailureOverlay
@onready var _restart_button: Button = %RestartButton


# 保留 Scene 的全部设计矩形，只订阅窗口变化并初始化显示。
func _ready() -> void:
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


# PK 唯一值归 HitResolution，HUD 只将它映射为玩家占比和对手占比。
func refresh_pk(player_pk: float, current_tier: int) -> void:
	var player_share: float = clampf(player_pk, 0.0, 1.0)
	_pk_progress.value = player_share
	_player_pk_label.text = "玩家 PK %.1f%%" % (player_share * 100.0)
	_opponent_pk_label.text = "对手 %.1f%%" % ((1.0 - player_share) * 100.0)
	_tier_label.text = "Tier %d" % current_tier


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
	# 顶部状态区只有两行；消息内部换行统一显示为分隔符，保持反馈完整可读。
	_battle_state.text = message.replace("\n", " · ")


# 失败只切换可见界面；停止输入、回拉和生成继续由各状态拥有者处理。
func show_failure() -> void:
	_failure_overlay.show()
	_restart_button.grab_focus()


# 重开仅复位界面提示，各系统的本场状态由 Sandbox 分别初始化。
func reset_for_attempt() -> void:
	_failure_overlay.hide()
	show_battle_state("瞄准弹幕，蓄满后松开左键")
	refresh_attack(0.0, AttackChargeInput.AttackPhase.READY)
