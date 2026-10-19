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
@onready var _plan_b_status_title: Label = %PlanBStatusTitle
@onready var _plan_b_status_label: Label = %PlanBStatusLabel
@onready var _opponent_publish_button: Button = %OpponentPublishButton
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
	get_viewport().size_changed.connect(_fit_viewport_height)
	_fit_viewport_height()
	%CloseButton.pressed.connect(_close_panel)
	%RestartButton.pressed.connect(_restart_current_battle)
	%ClearBarragesButton.pressed.connect(_clear_barrages)
	%SpawnBatchButton.pressed.connect(_spawn_normal_batch)
	%StopGenerationButton.pressed.connect(_set_generation_enabled.bind(false))
	%ResumeGenerationButton.pressed.connect(_set_generation_enabled.bind(true))
	%ApplyLiveDataButton.pressed.connect(_apply_live_data)
	%ApplyTendenciesButton.pressed.connect(_apply_tendencies)
	_opponent_publish_button.pressed.connect(_toggle_plan_b_opponent_publish)
	for child in _pk_buttons.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		var percentage: int = str(button.name).trim_prefix("PK").to_int()
		button.pressed.connect(_set_player_pk.bind(percentage))
	_refresh_snapshot()


# 默认逻辑视口可能低于设计高度，限制面板高度以保留内部滚动入口。
func _fit_viewport_height() -> void:
	var available_height: float = maxf(get_viewport().get_visible_rect().size.y - 32.0, 0.0)
	$CenterContainer/PanelContainer.custom_minimum_size.y = minf(760.0, available_height)


# 由 Sandbox 注入当前场景作为状态读取与调试操作入口。
func bind_sandbox(sandbox: Node) -> void:
	_sandbox = sandbox
	if not is_node_ready():
		return
	_message_label.text = "已连接当前 Sandbox；状态和操作结果按实时数据确认。"
	_refresh_snapshot()


# 仅在面板打开时定时刷新显示，不阻塞游戏流程。
func _process(delta: float) -> void:
	if not visible:
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
	if not is_instance_valid(_sandbox) or not _sandbox.has_method("get_debug_snapshot"):
		_set_actions_enabled({})
		_set_mode_visibility({})
		_battle_phase_label.text = "战斗阶段：尚未绑定当前战斗"
		_message_label.text = "独立预览仅显示界面；请由战斗场景绑定后操作。"
		return
	var snapshot: Dictionary = _sandbox.call("get_debug_snapshot")
	_set_actions_enabled(snapshot)
	_set_mode_visibility(snapshot)
	if snapshot.is_empty():
		_battle_phase_label.text = "战斗阶段：等待当前战斗初始化"
		_message_label.text = "Sandbox 已连接；战斗状态尚未就绪，调试操作已禁用。"
		return
	_battle_phase_label.text = "战斗阶段：%s" % str(snapshot.get("battle_phase", "未知"))
	_level_label.text = "当前关卡：%s" % str(snapshot.get("level", "未知"))
	_streamer_label.text = "我方主播：%s    对手主播：%s" % [
		str(snapshot.get("player_streamer", "未知")),
		str(snapshot.get("opponent_streamer", "未知")),
	]
	_pk_label.text = "玩家 PK：%.1f%%" % (float(snapshot.get("player_pk", 0.0)) * 100.0)
	_tier_label.text = "当前 Tier：%d" % int(snapshot.get("tier", 0))
	if bool(snapshot.get("is_plan_b_campaign", false)) and not str(snapshot.get("battle_phase", "")).contains("CONTRADICTION_BREAK"):
		_attack_label.text = "攻击阶段：普通阶段使用棋盘卡槽发表"
	else:
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
	if bool(snapshot.get("is_plan_b_campaign", false)):
		var plan_b_snapshot: Dictionary = snapshot.get("plan_b", {})
		_plan_b_status_label.text = _format_plan_b_status(plan_b_snapshot)
		var publish_enabled: bool = bool(plan_b_snapshot.get("opponent_auto_publish_enabled", false))
		_opponent_publish_button.text = "暂停对手主动发表" if publish_enabled else "恢复对手主动发表"
		_generation_label.text = str(snapshot.get("legacy_barrage_hint", ""))
	else:
		_generation_label.text = "普通弹幕生成：%s" % (
			"运行中" if bool(snapshot.get("normal_generation_enabled", false)) else "已停止"
		)


# 按当前 Sandbox 快照逐项启用确实可操作的调试入口。
func _set_actions_enabled(snapshot: Dictionary) -> void:
	var has_snapshot: bool = not snapshot.is_empty()
	var can_set_pk: bool = has_snapshot and bool(snapshot.get("can_set_player_pk", true))
	for child in _pk_buttons.get_children():
		if child is Button:
			child.disabled = not can_set_pk
	%RestartButton.disabled = not has_snapshot or not bool(snapshot.get("can_restart", false))
	%ClearBarragesButton.disabled = not has_snapshot or not bool(snapshot.get("can_clear_barrages", false))
	%SpawnBatchButton.disabled = not has_snapshot or not bool(snapshot.get("can_spawn_normal_batch", false))
	%StopGenerationButton.disabled = not has_snapshot or not bool(snapshot.get("can_toggle_normal_generation", false))
	%ResumeGenerationButton.disabled = not has_snapshot or not bool(snapshot.get("can_toggle_normal_generation", false))
	%ApplyLiveDataButton.disabled = not has_snapshot
	%ApplyTendenciesButton.disabled = not has_snapshot
	_opponent_publish_button.disabled = (
		not has_snapshot or not bool(snapshot.get("can_toggle_opponent_publish", false))
	)
	for input_control: SpinBox in [
		_viewer_input, _like_input, _comment_input, _fan_input,
		_orthodox_input, _heretical_input, _absurd_input,
	]:
		input_control.editable = has_snapshot


func _set_mode_visibility(snapshot: Dictionary) -> void:
	var plan_b_mode: bool = bool(snapshot.get("is_plan_b_campaign", false))
	_plan_b_status_title.visible = plan_b_mode
	_plan_b_status_label.visible = plan_b_mode
	_opponent_publish_button.visible = plan_b_mode
	_barrage_label.visible = not plan_b_mode
	%BarrageTitle.text = "旧弹幕调试入口" if plan_b_mode else "弹幕与战斗操作"


func _format_plan_b_status(snapshot: Dictionary) -> String:
	var populations: Dictionary = snapshot.get("faction_counts", {})
	var hand: Array = snapshot.get("player_hand", [])
	var slot_states: Array = snapshot.get("player_slot_states", [])
	var slot_texts: PackedStringArray = []
	for slot_id: int in 3:
		var card: Dictionary = hand[slot_id] if slot_id < hand.size() and hand[slot_id] is Dictionary else {}
		var slot_state: Dictionary = (
			slot_states[slot_id]
			if slot_id < slot_states.size() and slot_states[slot_id] is Dictionary
			else {}
		)
		var word_text: String = str(card.get("text", card.get("word_id", "空槽")))
		if word_text.is_empty():
			word_text = "空槽"
		var remaining: float = float(slot_state.get("remaining", 0.0))
		var availability: String = "冷却 %.1f 秒" % remaining if remaining > 0.0 else "可用"
		slot_texts.append("%d：%s（%s）" % [slot_id + 1, word_text, availability])
	var director: Dictionary = snapshot.get("opponent_director", {})
	var auto_publish_enabled: bool = bool(snapshot.get("opponent_auto_publish_enabled", false))
	var speech_enabled: bool = bool(director.get("speech_enabled", false))
	var counterattack_enabled: bool = (
		bool(snapshot.get("opponent_counterattack_enabled", false))
		and bool(director.get("counterattack_enabled", false))
	)
	var publish_state: String = "运行中" if auto_publish_enabled and speech_enabled else "已暂停"
	if not speech_enabled:
		publish_state = "当前关卡未启用"
	return "棋子人口：我方 %d / 对手 %d / 中立 %d\n玩家三槽：%s\n对手主动发表：%s；冷却 %.1f 秒；反击%s" % [
		int(populations.get("player", 0)),
		int(populations.get("opponent", 0)),
		int(populations.get("neutral", 0)),
		"；".join(slot_texts),
		publish_state,
		float(director.get("speech_cooldown_remaining", 0.0)),
		"开启" if counterattack_enabled else "关闭",
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
	if not is_instance_valid(_sandbox) or not _sandbox.has_method("get_debug_snapshot"):
		return
	var snapshot: Dictionary = _sandbox.call("get_debug_snapshot")
	if snapshot.is_empty():
		return
	_viewer_input.value = int(snapshot.get("viewer_count", 0))
	_like_input.value = int(snapshot.get("like_count", 0))
	_comment_input.value = int(snapshot.get("comment_count", 0))
	_fan_input.value = int(snapshot.get("fan_count", 0))
	_orthodox_input.value = int(snapshot.get("attempt_orthodox", 0))
	_heretical_input.value = int(snapshot.get("attempt_heretical", 0))
	_absurd_input.value = int(snapshot.get("attempt_absurd", 0))


# 通过当前玩法的正式 PK 所有者设置并回读 PK、Tier。
func _set_player_pk(percentage: int) -> void:
	var target_pk: float = float(percentage) / 100.0
	var result: Dictionary = _sandbox.call("debug_set_player_pk_with_status", target_pk)
	var snapshot: Dictionary = _sandbox.call("get_debug_snapshot")
	var actual_pk: float = float(snapshot.get("player_pk", 0.0))
	_refresh_snapshot()
	if bool(result.get("ok", false)) and is_equal_approx(actual_pk, target_pk):
		_message_label.text = "玩家 PK 已回读为 %.1f%%，当前 Tier %d。" % [
			actual_pk * 100.0, int(snapshot.get("tier", 0)),
		]
	else:
		_message_label.text = "PK 设置未生效；当前真实值 %.1f%%。" % (actual_pk * 100.0)


# 沿用 Sandbox 当前关重开流程。
func _restart_current_battle() -> void:
	var accepted: bool = bool(_sandbox.call("debug_restart_current_attempt"))
	var snapshot: Dictionary = _sandbox.call("get_debug_snapshot")
	var restarted: bool = false
	if bool(snapshot.get("is_plan_b_campaign", false)):
		var plan_b_snapshot: Dictionary = snapshot.get("plan_b", {})
		restarted = str(plan_b_snapshot.get("battle_state", "")) == "running"
	else:
		restarted = bool(snapshot.get("normal_combat_active", false))
	_refresh_snapshot()
	_sync_inputs_from_snapshot()
	_message_label.text = "当前战斗已重开。" if accepted and restarted else "重开未生效；请检查当前阶段状态。"


# 清空场上弹幕和已排队的普通复读。
func _clear_barrages() -> void:
	var succeeded: bool = bool(_sandbox.call("debug_clear_barrages"))
	_refresh_snapshot()
	_message_label.text = "弹幕与等待复读已清空。" if succeeded else "当前阶段无法清空旧弹幕，场上状态未确认为空。"


# 请求 BarrageArea 按当前关配置立即生成一批普通弹幕。
func _spawn_normal_batch() -> void:
	var spawned_count: int = int(_sandbox.call("debug_spawn_normal_batch"))
	_refresh_snapshot()
	_message_label.text = "本次已生成 %d 条普通弹幕。" % spawned_count if spawned_count > 0 else "当前战斗未生成普通弹幕。"


# 按钮只切换普通弹幕生成器的真实运行状态。
func _set_generation_enabled(enabled: bool) -> void:
	var succeeded: bool = bool(_sandbox.call("debug_set_normal_generation_enabled", enabled))
	var snapshot: Dictionary = _sandbox.call("get_debug_snapshot")
	var actual_enabled: bool = bool(snapshot.get("normal_generation_enabled", false))
	_refresh_snapshot()
	if succeeded and actual_enabled == enabled:
		_message_label.text = "普通弹幕生成已%s。" % ("恢复" if enabled else "停止")
	else:
		_message_label.text = "普通弹幕生成状态未改变，当前为%s。" % ("运行中" if actual_enabled else "已停止")


# 把输入框值交给当前 LiveSessionData 并刷新画面反馈。
func _apply_live_data() -> void:
	var succeeded: bool = bool(_sandbox.call(
		"debug_set_live_data",
		int(_viewer_input.value),
		int(_like_input.value),
		int(_comment_input.value),
		int(_fan_input.value)
	))
	_refresh_snapshot()
	_sync_inputs_from_snapshot()
	_message_label.text = "已写入并回读我方直播数据。" if succeeded else "直播数据写入失败；保留当前真实值。"


# 倾向修改限制在当前关未提交的暂存值。
func _apply_tendencies() -> void:
	var succeeded: bool = bool(_sandbox.call(
		"debug_set_attempt_tendencies",
		int(_orthodox_input.value),
		int(_heretical_input.value),
		int(_absurd_input.value)
	))
	_refresh_snapshot()
	_sync_inputs_from_snapshot()
	_message_label.text = "已写入并回读当前关倾向。" if succeeded else "倾向写入失败；保留当前真实值。"


func _toggle_plan_b_opponent_publish() -> void:
	if not is_instance_valid(_sandbox) or not _sandbox.has_method("get_debug_snapshot"):
		_message_label.text = "当前 Sandbox 尚未绑定。"
		return
	var before: Dictionary = _sandbox.call("get_debug_snapshot")
	var plan_b_before: Dictionary = before.get("plan_b", {})
	var desired_enabled: bool = not bool(plan_b_before.get("opponent_auto_publish_enabled", false))
	var accepted: bool = bool(_sandbox.call(
		"debug_set_plan_b_opponent_auto_publish_enabled", desired_enabled
	))
	var after: Dictionary = _sandbox.call("get_debug_snapshot")
	var plan_b_after: Dictionary = after.get("plan_b", {})
	var actual_enabled: bool = bool(plan_b_after.get("opponent_auto_publish_enabled", false))
	_refresh_snapshot()
	if accepted and actual_enabled == desired_enabled:
		_message_label.text = "对手主动发表已%s。" % ("恢复" if desired_enabled else "暂停")
	else:
		_message_label.text = "对手主动发表状态未改变；请查看当前关卡与战斗状态。"


# 关闭整个调试 CanvasLayer，F3 可再次打开。
func _close_panel() -> void:
	visible = false
