extends Control

const SAMPLE_LEVEL_CATALOG: LevelCatalog = preload("res://data/level_configuration/level_catalog.tres")
const SAMPLE_TIER_CATALOG: CombatStageTierCatalog = preload("res://data/combat_stage/tier_catalog.tres")
const CONTRADICTION_WINDOW_CONFIG: ContradictionWindowConfig = preload("res://systems/contradiction_break/contradiction_window_config.tres")
@export var battle_config: SandboxBattleConfig = preload("res://data/sandbox/playable_battle_config.tres")

@onready var _barrage_area: BarrageArea = %BarrageArea
@onready var _aim_reticle: AimReticle = %AimReticle
@onready var _attack_charge_input: AttackChargeInput = %AttackChargeInput
@onready var _battle_hud = %BattleHud

var _hit_resolution: HitResolution
var _combat_stage: CombatStage
var _opponent_pk_bar: OpponentPKBar
var _repeat_queue: RepeatDelayQueue
var _run_state: LevelRunState
var _normal_combat_active: bool = false
var _contradiction_stage_active: bool = false
var _contradiction_break: ContradictionBreakSystem
var _opening_fan_count: int = 0


# 场景只创建生命周期对象并接线；PK、Tier、倾向等状态留在各自所有者。
func _ready() -> void:
	# 直接运行场景时等待 Autoload 完成初始化，再创建周目并显式绑定已就绪的子 HUD。
	if SaveManager.data == null:
		SaveManager.new_game()
	%LiveDataHud.bind_live_session(SaveManager.data.live_session)
	_run_state = LevelRunState.new(SAMPLE_LEVEL_CATALOG)
	_opening_fan_count = SaveManager.data.live_session.fan_count
	_opponent_pk_bar = OpponentPKBar.new()
	_opponent_pk_bar.name = "OpponentPKBar"
	add_child(_opponent_pk_bar)
	_opponent_pk_bar.attempt_failed.connect(_on_attempt_failed)
	_barrage_area.barrage_generated.connect(_on_barrage_generated)
	_attack_charge_input.shot_hit_resolution_submitted.connect(_on_shot_hit_resolution_submitted)
	_attack_charge_input.shot_snapshot_created.connect(_on_contradiction_shot_created)
	_attack_charge_input.shot_arrival_resolved.connect(_on_contradiction_shot_arrived)
	_attack_charge_input.configure_target_query(_aim_reticle, _barrage_area)
	%RestartButton.pressed.connect(restart_current_attempt)
	%PauseMenu.restart_requested.connect(restart_current_attempt)
	restart_current_attempt()


# 原地重开同一关；替换本场结算和队列，保留当前关卡及此前周目成果。
func restart_current_attempt() -> void:
	_stop_normal_combat()
	_contradiction_stage_active = false
	if _contradiction_break != null:
		remove_child(_contradiction_break)
		_contradiction_break.queue_free()
		_contradiction_break = null
	_attack_charge_input.set_contradiction_mode(false)
	%PauseMenu.resume_game()
	_opponent_pk_bar.reset_current_attempt()
	SaveManager.data.tendency_state.rollback_attempt_tendency()
	SaveManager.data.live_session.initialize_session(_opening_fan_count)
	_hit_resolution = HitResolution.new(
		battle_config.initial_player_pk,
		battle_config.minimum_player_pk,
		battle_config.maximum_player_pk
	)
	_repeat_queue = RepeatDelayQueue.new(battle_config.maximum_pending_repeat_count)
	_combat_stage = CombatStage.new(SAMPLE_TIER_CATALOG)
	# Tier 的同步回调必须先于场景读取结果，复读计划才能使用整发结算后的档位。
	_combat_stage.bind_hit_resolution(_hit_resolution)
	_combat_stage.bind_barrage_area(_barrage_area)
	_combat_stage.bind_opponent_pk_bar(_opponent_pk_bar)
	_combat_stage.bind_audio_manager(AudioManager)
	_combat_stage.tier_state_changed.connect(_on_tier_state_changed)
	_hit_resolution.final_player_pk_updated.connect(_on_final_player_pk_updated)
	_barrage_area.base_lifetime_seconds = battle_config.normal_lifetime_seconds
	_barrage_area.repeat_barrage_screen_cap = battle_config.repeat_screen_cap
	_battle_hud.reset_for_attempt()
	_combat_stage.begin_combat()
	var current_level: LevelProfile = _run_state.get_current_level_profile()
	if current_level == null:
		_battle_hud.show_battle_state("当前没有关卡配置")
		return
	var player_name: String = SaveManager.data.streamer_name
	_battle_hud.configure_streamers(player_name if not player_name.is_empty() else "玩家主播", current_level.streamer_name)
	if not _attack_charge_input.configure_attack_timing(battle_config.attack_timing):
		push_error("Sandbox: 攻击时长配置无效。")
		return
	if not _attack_charge_input.configure_hit_resolution(_hit_resolution):
		push_error("Sandbox: 无法接入本场命中结算。")
		return
	_normal_combat_active = true
	_attack_charge_input.set_combat_active(true)
	if not _barrage_area.start_normal_generation(current_level):
		_stop_normal_combat()
		push_error("Sandbox: 无法启动普通弹幕生成。")
		return
	_opponent_pk_bar.start_pullback(_hit_resolution, battle_config.base_pullback_speed)
	_refresh_pk_feedback()


# 暂停由 SceneTree 冻结此节点，复读等待只使用实际游戏帧时间。
func _process(delta: float) -> void:
	if _normal_combat_active:
		_repeat_queue.advance_and_dispatch(delta, _barrage_area)
	elif _contradiction_stage_active and _contradiction_break != null and not _contradiction_break.is_result_locked():
		_battle_hud.show_battle_state("击破矛盾：%.1f 秒 · 剩余 %d 发" % [_contradiction_break.get_remaining_seconds(), _contradiction_break.get_remaining_shots()])
	_battle_hud.refresh_attack(_attack_charge_input.get_charge_progress(), _attack_charge_input.get_attack_phase())


# 正式满蓄发射才消耗矛盾机会；未蓄满取消没有快照事件。
func _on_contradiction_shot_created(_snapshot: AttackTargetSnapshot) -> void:
	if not _contradiction_stage_active or _contradiction_break == null:
		return
	if not _contradiction_break.register_launched_shot():
		_attack_charge_input.set_combat_active(false)


# 到达时只取仍存在的矛盾实例原句 ID；落空也交给 12 系统消耗本发机会。
func _on_contradiction_shot_arrived(_snapshot: AttackTargetSnapshot, target_results: Array[Dictionary]) -> void:
	if not _contradiction_stage_active or _contradiction_break == null:
		return
	var hit_ids: Array[String] = []
	for target_result: Dictionary in target_results:
		var view := target_result.get("target") as BarrageView
		if view == null or view.runtime_record == null or not view.runtime_record.is_contradiction:
			continue
		hit_ids.append(view.runtime_record.original_sentence_id)
		_barrage_area.end_barrage(int(target_result.get("target_instance_id", -1)))
	_contradiction_break.resolve_shot_hit_ids(hit_ids)


# 已锁定结果立即停止攻击和矛盾生成；后续分支只读取这一份结果。
func _on_contradiction_outcome_locked(outcome: int) -> void:
	_attack_charge_input.set_combat_active(false)
	_barrage_area.clear_barrages()
	if outcome == ContradictionBreakSystem.Outcome.BREAKTHROUGH:
		_battle_hud.show_battle_state("矛盾击破成功")
	else:
		_battle_hud.show_battle_state("PK 胜利 · 未击破矛盾")


# 普通与复读都由同一生成事实计评论，等待请求和失败生成不提前入账。
func _on_barrage_generated(_view: BarrageView) -> void:
	SaveManager.data.live_session.record_generated_comments(1)


# 完成整发结算后协调移除、倾向和复读，收益继续读取 HitResolution 的逐目标结果。
func _on_shot_hit_resolution_submitted(_snapshot: AttackTargetSnapshot, submission: Dictionary) -> void:
	if not _normal_combat_active:
		return
	var result: Dictionary = submission.get("hit_resolution_result", {})
	if bool(result.get("cancelled_by_zero_pk", false)):
		return
	var normal_hit_count: int = 0
	var repeat_hit_count: int = 0
	for target_result: Dictionary in result.get("target_results", []):
		var trait_result := target_result.get("trait_result") as BarrageTraitResult
		if trait_result == null:
			continue
		# 只有遮挡未命中的目标留场；其余到达结果结束实例，收益由结算结果独立决定。
		if trait_result.kind != BarrageTraitResult.Kind.OCCLUSION:
			_barrage_area.end_barrage(int(target_result.get("target_instance_id", -1)))
		if not bool(target_result.get("is_valid_hit", false)) or not trait_result.receives_normal_reward:
			continue
		if bool(target_result.get("is_repeat", false)):
			repeat_hit_count += 1
			continue
		normal_hit_count += 1
		SaveManager.data.tendency_state.record_normal_speech_tendency(
			str(target_result.get("tendency_id", "")), int(target_result.get("tendency_delta", 0))
		)
		var plan: RepeatPlan = RepeatPlan.create_normal_hit_plan(
			StringName(target_result.get("original_sentence_id", "")),
			str(target_result.get("original_sentence_text", "")),
			_combat_stage.get_current_tier(),
			_combat_stage.get_current_repeat_count_per_hit(),
			battle_config.repeat_lifetime_seconds
		)
		plan.apply_display_template(battle_config.repeat_display_template)
		_repeat_queue.enqueue_plan(plan)
	if normal_hit_count > 0:
		_battle_hud.show_battle_state("命中 %d 条 · PK +%.2f%% · 等待复读" % [normal_hit_count, float(result.get("total_pk_delta", 0.0)) * 100.0])
	elif repeat_hit_count > 0:
		_battle_hud.show_battle_state("复读命中 %d 条 · 零收益" % repeat_hit_count)
	else:
		_battle_hud.show_battle_state("未命中有效话语")
	if _hit_resolution.get_player_pk() >= battle_config.maximum_player_pk:
		_complete_normal_combat()


# 满值先立刻停回拉和生成；攻击提交完本发事实后统一停止输入和清理。
func _on_final_player_pk_updated(player_pk: float) -> void:
	_refresh_pk_feedback()
	if _normal_combat_active and player_pk >= battle_config.maximum_player_pk:
		_opponent_pk_bar.stop_pullback()
		_barrage_area.stop_normal_generation()
		_complete_normal_combat.call_deferred()


# 档位反馈读取系统当前值，UI 不保存第二份可写 Tier。
func _on_tier_state_changed(_current_tier: int) -> void:
	_refresh_pk_feedback()


# 对手份额由玩家唯一 PK 即时派生，所有 PK 修改都留在 HitResolution。
func _refresh_pk_feedback() -> void:
	_battle_hud.refresh_pk(_hit_resolution.get_player_pk(), _combat_stage.get_current_tier())


# 失败只执行一次，回滚本场暂存后开放当前关重开。
func _on_attempt_failed() -> void:
	if not _normal_combat_active:
		return
	_opponent_pk_bar.record_current_level_failure()
	_stop_normal_combat()
	SaveManager.data.tendency_state.rollback_attempt_tendency()
	_battle_hud.show_failure()


# 普通 PK 满后读取本关矛盾内容，并把当前档位参数下的生成交给弹幕系统。
func _complete_normal_combat() -> void:
	if not _normal_combat_active or _hit_resolution.get_player_pk() < battle_config.maximum_player_pk:
		return
	_stop_normal_combat()
	_contradiction_stage_active = true
	_contradiction_break = ContradictionBreakSystem.new()
	add_child(_contradiction_break)
	_contradiction_break.outcome_locked.connect(_on_contradiction_outcome_locked)
	var current_level: LevelProfile = _run_state.get_current_level_profile()
	if not _contradiction_break.load_level_content(current_level):
		push_error("Sandbox: 当前关卡没有可用的矛盾内容。")
		return
	if not _barrage_area.start_contradiction_generation(
		current_level,
		_contradiction_break.get_true_contradictions(),
		_contradiction_break.get_false_contradictions()
	):
		push_error("Sandbox: 无法启动真假矛盾生成。")
		return
	if not _contradiction_break.start_window(CONTRADICTION_WINDOW_CONFIG):
		_barrage_area.stop_contradiction_generation()
		push_error("Sandbox: 无法启动矛盾限时窗口。")
		return
	_attack_charge_input.set_contradiction_mode(true)
	_attack_charge_input.set_combat_active(true)
	_battle_hud.show_battle_state("矛盾阶段：寻找真正的矛盾")


# 阶段结束显式停止系统，避免旧输入或等待请求在下一次尝试继续推进。
func _stop_normal_combat() -> void:
	_normal_combat_active = false
	_attack_charge_input.set_combat_active(false)
	_barrage_area.stop_normal_generation()
	_barrage_area.clear_barrages()
	if _opponent_pk_bar != null:
		_opponent_pk_bar.stop_pullback()
	if _repeat_queue != null:
		_repeat_queue.clear_normal_queue()


# 离开验收场时撤销尚未提交的本场倾向，已有周目成果由 SaveData 保留。
func _exit_tree() -> void:
	if SaveManager.data != null:
		SaveManager.data.tendency_state.rollback_attempt_tendency()
