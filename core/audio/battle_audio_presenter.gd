## 只消费真实攻击、生成和整发结果，声音不回写战斗数值。
extends Node

@export_range(0.0, 1.0, 0.01) var spawn_sound_interval_seconds: float = 0.15
var _attack: AttackChargeInput
var _area: BarrageArea
var _held: bool = false
var _full: bool = false
var _spawn_remaining: float = 0.0
var _audio: Node
var _flow_connections: Array[Dictionary] = []


# 同一 HUD 复用本场输入源；重新绑定先解除旧订阅。
func bind_sources(attack: AttackChargeInput, area: BarrageArea) -> void:
	_audio = get_node_or_null("/root/AudioManager")
	if is_instance_valid(_attack):
		_attack.shot_snapshot_created.disconnect(_on_shot)
		_attack.shot_hit_resolution_submitted.disconnect(_on_resolved)
	if is_instance_valid(_area):
		_area.barrage_generated.disconnect(_on_generated)
	_attack = attack
	_area = area
	_held = false
	_full = false
	if is_instance_valid(_attack):
		_attack.shot_snapshot_created.connect(_on_shot)
		_attack.shot_hit_resolution_submitted.connect(_on_resolved)
	if is_instance_valid(_area):
		_area.barrage_generated.connect(_on_generated)


# 输入当前没有蓄力信号，直接读现有公开状态，按上升沿各播放一次。
func _process(delta: float) -> void:
	_spawn_remaining = maxf(0.0, _spawn_remaining - delta)
	if not is_instance_valid(_attack):
		return
	var held: bool = _attack.is_charge_held()
	var full: bool = _attack.is_fully_charged()
	if held and not _held:
		_play(&"attack_charge")
	if held and full and not _full:
		_play(&"attack_ready")
	_held = held
	_full = full


# 正式发射快照是一发一次的声音来源，命中与蓄力刷新均不重复发射音。
func _on_shot(_snapshot: AttackTargetSnapshot) -> void:
	_play(&"attack_fire")


# 高频生成共用短限流；复读按实际成功实例播放，排队失败不会出声。
func _on_generated(view: BarrageView) -> void:
	if view.runtime_record == null or _spawn_remaining > 0.0:
		return
	var runtime: BarrageRuntimeRecord = view.runtime_record
	_play(&"repeat_batch" if runtime.is_repeat else &"barrage_spawn")
	_spawn_remaining = spawn_sound_interval_seconds


# 沿用 HitResolution 的结果事实，陷阱优先于普通命中；复读零收益保持安静。
func _on_resolved(_snapshot: AttackTargetSnapshot, submission: Dictionary) -> void:
	var result: Dictionary = submission.get("hit_resolution_result", {})
	if bool(result.get("cancelled_by_zero_pk", false)) or bool(result.get("terminal_mode", false)):
		return
	var normal_count: int = 0
	var trap_hit: bool = false
	for target: Dictionary in result.get("target_results", []):
		var trait_result: BarrageTraitResult = target.get("trait_result") as BarrageTraitResult
		if trait_result != null and trait_result.kind in [BarrageTraitResult.Kind.FAKE_CARD, BarrageTraitResult.Kind.RETALIATION_COPY, BarrageTraitResult.Kind.REFLECT]:
			trap_hit = true
		if bool(target.get("is_valid_hit", false)) and not bool(target.get("is_repeat", false)):
			normal_count += 1
	if trap_hit:
		_play(&"hit_trap")
	elif normal_count > 0:
		_play(&"hit_normal")


# 调用既有 Autoload 入口，解析检查与独立 HUD 加载无需全局标识符注入。
func _play(event_id: StringName) -> void:
	if is_instance_valid(_audio):
		_audio.call("play_event", event_id)


# 根场景统一注入已创建的阶段对象；解绑不触碰这些对象的生命周期。
func bind_flows(oracle_flow: ContradictionOracleFlow, divine_flow: DivineDescentFlow = null) -> void:
	_disconnect_flows()
	if oracle_flow != null:
		_connect_fact(oracle_flow.entered, _on_contradiction_entered)
		_connect_fact(oracle_flow.outcome_resolved, _on_contradiction_result)
		_connect_fact(oracle_flow.oracle_opened, _on_oracle_opened.bind(oracle_flow))
	if divine_flow != null:
		_connect_fact(divine_flow.entered, _on_divine_entered)


# 保存本组件建立的连接，重开绑定不会叠加回调。
func _connect_fact(source: Signal, callback: Callable) -> void:
	if source.is_connected(callback):
		return
	source.connect(callback)
	_flow_connections.append({"signal": source, "callback": callback})


# 只断开仍存活的业务来源。
func _disconnect_flows() -> void:
	for connection: Dictionary in _flow_connections:
		var source: Signal = connection["signal"]
		var callback: Callable = connection["callback"]
		if is_instance_valid(source.get_object()) and source.is_connected(callback):
			source.disconnect(callback)
	_flow_connections.clear()


# 进入可操作矛盾窗口才播放阶段音，不在提前 PK 满时播放。
func _on_contradiction_entered(_system: ContradictionBreakSystem) -> void:
	_play(&"contradiction_start")


# 成功结果与业务点赞短增使用同一已锁定事实，失败分支保持原声音。
func _on_contradiction_result(outcome: int) -> void:
	if outcome == ContradictionBreakSystem.Outcome.BREAKTHROUGH:
		_play(&"contradiction_break")
		_play(&"live_like_burst")


# 确认对象每场由 13 创建；只监听本场真正的提交成功通知。
func _on_oracle_opened(_session: FinalOracleSession, flow: ContradictionOracleFlow) -> void:
	var confirmation: FinalOracleConfirmationState = flow.get_confirmation_state()
	if confirmation != null:
		_connect_fact(confirmation.confirmation_committed, _on_oracle_confirmed)


# 未确认的候选变化不播放确认音。
func _on_oracle_confirmed(_run: SaveData, _level_id: String, _candidate: Dictionary) -> void:
	_play(&"oracle_confirm")
	_play(&"live_like_burst")


# 成功建立终局会话后播放；锁句音继续由现有 DivineDescentSpread 负责。
func _on_divine_entered(_session: DivineDescentSession) -> void:
	_play(&"divine_descent_start")


# 离树显式断开信号，避免旧 HUD 仍消费下一场输入。
func _exit_tree() -> void:
	_disconnect_flows()
	bind_sources(null, null)
