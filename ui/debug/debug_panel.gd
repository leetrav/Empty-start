extends CanvasLayer

const REFRESH_INTERVAL: float = 0.25

@onready var _pk_buttons: GridContainer = %PKPresetGrid
@onready var _battle_phase_label: Label = %BattlePhaseLabel
@onready var _level_label: Label = %LevelLabel
@onready var _streamer_label: Label = %StreamerLabel
@onready var _pk_label: Label = %PKLabel
@onready var _tier_label: Label = %TierLabel
@onready var _attack_label: Label = %AttackLabel
@onready var _barrage_label: Label = %BarrageLabel
@onready var _generation_label: Label = %GenerationLabel
@onready var _live_data_label: Label = %LiveDataLabel
@onready var _tendency_label: Label = %TendencyLabel
@onready var _message_label: Label = %MessageLabel
@onready var _viewer_input: SpinBox = %ViewerInput
@onready var _like_input: SpinBox = %LikeInput
@onready var _comment_input: SpinBox = %CommentInput
@onready var _fan_input: SpinBox = %FanInput
@onready var _orthodox_input: SpinBox = %OrthodoxInput
@onready var _heretical_input: SpinBox = %HereticalInput
@onready var _absurd_input: SpinBox = %AbsurdInput

var _sandbox: Node
var _refresh_elapsed: float = 0.0


# 连接静态界面按钮；面板始终可响应 F3，显示时才轮询实时状态。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%CloseButton.pressed.connect(_close_panel)
	%RestartButton.pressed.connect(_restart_current_battle)
	%ClearBarragesButton.pressed.connect(_clear_barrages)
	%SpawnBatchButton.pressed.connect(_spawn_normal_batch)
	%StopGenerationButton.pressed.connect(_set_generation_enabled.bind(false))
	%ResumeGenerationButton.pressed.connect(_set_generation_enabled.bind(true))
	%ApplyLiveDataButton.pressed.connect(_apply_live_data)
	%ApplyTendenciesButton.pressed.connect(_apply_tendencies)
	for child in _pk_buttons.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		var percentage: int = str(button.name).trim_prefix("PK").to_int()
		button.pressed.connect(_set_player_pk.bind(percentage))


# 由 Sandbox 注入当前场景作为状态读取与调试操作入口。
func bind_sandbox(sandbox: Node) -> void:
	_sandbox = sandbox
	_refresh_snapshot()


# 仅在面板打开时定时刷新显示，不阻塞游戏流程。
func _process(delta: float) -> void:
	if not visible or _sandbox == null:
		return
	_refresh_elapsed += delta
	if _refresh_elapsed < REFRESH_INTERVAL:
		return
	_refresh_elapsed = 0.0
	_refresh_snapshot()


# F3 只切换调试层并消费该动作，不影响暂停和鼠标攻击输入。
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("debug_panel"):
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	visible = not visible
	if visible:
		_refresh_snapshot()
		_sync_inputs_from_snapshot()
		%CloseButton.grab_focus()
	get_viewport().set_input_as_handled()


# 从 Sandbox 即时读取业务快照并映射到只读状态标签。
func _refresh_snapshot() -> void:
	if _sandbox == null or not _sandbox.has_method("get_debug_snapshot"):
		return
	var snapshot: Dictionary = _sandbox.call("get_debug_snapshot")
	if snapshot.is_empty():
		return
	_battle_phase_label.text = "战斗阶段：%s" % str(snapshot.get("battle_phase", "未知"))
	_level_label.text = "当前关卡：%s" % str(snapshot.get("level", "未知"))
	_streamer_label.text = "我方主播：%s    对手主播：%s" % [
		str(snapshot.get("player_streamer", "未知")),
		str(snapshot.get("opponent_streamer", "未知")),
	]
	_pk_label.text = "玩家 PK：%.1f%%" % (float(snapshot.get("player_pk", 0.0)) * 100.0)
	_tier_label.text = "当前 Tier：%d" % int(snapshot.get("tier", 0))
	_attack_label.text = "攻击阶段：%s" % _get_attack_phase_text(snapshot)
	_barrage_label.text = "普通弹幕：%d    复读弹幕：%d" % [
		int(snapshot.get("normal_barrage_count", 0)),
		int(snapshot.get("repeat_barrage_count", 0)),
	]
	_generation_label.text = "普通弹幕生成：%s" % ("运行中" if bool(snapshot.get("normal_generation_enabled", false)) else "已停止")
	_live_data_label.text = "观看 %d    点赞 %d    评论 %d    粉丝 %d" % [
		int(snapshot.get("viewer_count", 0)),
		int(snapshot.get("like_count", 0)),
		int(snapshot.get("comment_count", 0)),
		int(snapshot.get("fan_count", 0)),
	]
	_tendency_label.text = "本场倾向：正统 %d    异端 %d    荒谬 %d" % [
		int(snapshot.get("attempt_orthodox", 0)),
		int(snapshot.get("attempt_heretical", 0)),
		int(snapshot.get("attempt_absurd", 0)),
	]


# 将真实攻击阶段与按住状态翻译为中文说明。
func _get_attack_phase_text(snapshot: Dictionary) -> String:
	if bool(snapshot.get("is_charging", false)):
		return "蓄力中（CHARGING）"
	match int(snapshot.get("attack_phase", AttackChargeInput.AttackPhase.READY)):
		AttackChargeInput.AttackPhase.PROJECTILE_FLIGHT:
			return "弹幕飞行中（PROJECTILE_FLIGHT）"
		AttackChargeInput.AttackPhase.RECOVERY:
			return "攻击硬直（RECOVERY）"
		_:
			return "待机（READY）"


# 打开面板或应用修改后，将当前真实值填回输入框。
func _sync_inputs_from_snapshot() -> void:
	if _sandbox == null:
		return
	var snapshot: Dictionary = _sandbox.call("get_debug_snapshot")
	_viewer_input.value = int(snapshot.get("viewer_count", 0))
	_like_input.value = int(snapshot.get("like_count", 0))
	_comment_input.value = int(snapshot.get("comment_count", 0))
	_fan_input.value = int(snapshot.get("fan_count", 0))
	_orthodox_input.value = int(snapshot.get("attempt_orthodox", 0))
	_heretical_input.value = int(snapshot.get("attempt_heretical", 0))
	_absurd_input.value = int(snapshot.get("attempt_absurd", 0))


# 通过 HitResolution 的调试接口设置 PK。
func _set_player_pk(percentage: int) -> void:
	_sandbox.call("debug_set_player_pk", float(percentage) / 100.0)
	_refresh_snapshot()
	_message_label.text = "已通过命中结算更新玩家 PK。Tier 与 HUD 已读取正式变化。"


# 沿用 Sandbox 当前关重开流程。
func _restart_current_battle() -> void:
	_sandbox.call("restart_current_attempt")
	_refresh_snapshot()
	_sync_inputs_from_snapshot()
	_message_label.text = "已重新开始当前战斗。"


# 清空场上弹幕和已排队的普通复读。
func _clear_barrages() -> void:
	_sandbox.call("debug_clear_barrages")
	_refresh_snapshot()
	_message_label.text = "已清空当前弹幕和等待生成的复读。"


# 请求 BarrageArea 按当前关配置立即生成一批普通弹幕。
func _spawn_normal_batch() -> void:
	var spawned_count: int = int(_sandbox.call("debug_spawn_normal_batch"))
	_refresh_snapshot()
	_message_label.text = "本次立即生成 %d 条普通弹幕。" % spawned_count


# 按钮只切换普通弹幕生成器的真实运行状态。
func _set_generation_enabled(enabled: bool) -> void:
	var succeeded: bool = bool(_sandbox.call("debug_set_normal_generation_enabled", enabled))
	_refresh_snapshot()
	if succeeded:
		_message_label.text = "普通弹幕生成已%s。" % ("恢复" if enabled else "停止")
	else:
		_message_label.text = "当前没有可恢复的关卡生成配置。"


# 把输入框值交给当前 LiveSessionData 并刷新画面反馈。
func _apply_live_data() -> void:
	_sandbox.call(
		"debug_set_live_data",
		int(_viewer_input.value),
		int(_like_input.value),
		int(_comment_input.value),
		int(_fan_input.value)
	)
	_refresh_snapshot()
	_sync_inputs_from_snapshot()
	_message_label.text = "已写入当前我方 LiveSessionData。"


# 倾向修改限制在当前关未提交的暂存值。
func _apply_tendencies() -> void:
	_sandbox.call(
		"debug_set_attempt_tendencies",
		int(_orthodox_input.value),
		int(_heretical_input.value),
		int(_absurd_input.value)
	)
	_refresh_snapshot()
	_sync_inputs_from_snapshot()
	_message_label.text = "已写入当前关的倾向暂存值。"


# 关闭整个调试 CanvasLayer，F3 可再次打开。
func _close_panel() -> void:
	visible = false
