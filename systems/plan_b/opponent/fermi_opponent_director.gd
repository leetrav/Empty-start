class_name PlanBOpponentDirector
extends RefCounted

signal publish_word_requested(word_id: String, spawn_position: Vector2)
signal counterattack_windup_started(request: Dictionary)
signal counterattack_effect_requested(request: Dictionary)
signal counterattack_resolved(result: Dictionary)
signal opponent_word_pool_exhausted(level_id: String, streamer_id: String)

const SPAWN_MARGIN_PIXELS := 16.0
const COUNTERATTACK_SKILL_NAMES_ZH: Dictionary = {
	"alien": "分裂",
	"kiwi": "复制／改口反制",
	"frog": "吞食",
	"fox": "反弹",
}

var speech_enabled: bool = true
var counterattack_enabled: bool = true

var _content_catalog: Object
var _profile: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _counterattack_effect_handler: Callable = Callable()
var _level_id: String = ""
var _streamer_id: String = ""
var _spawn_area: Rect2 = Rect2()
var _speech_cooldown_remaining: float = 0.0
var _pending_speech_word_id: String = ""
var _awaiting_speech_publish_result: bool = false
var _counterattack_cooldown_remaining: float = 0.0
var _windup_remaining: float = 0.0
var _pending_counterattack: Dictionary = {}
var _awaiting_counterattack_result: bool = false
var _counterattack_uses: int = 0
var _counterattack_t2_qualified: bool = false
var _counterattack_t4_qualified: bool = false
var _counterattack_paused: bool = false
var _no_target_result_reported_by_tier: Dictionary = {}
var _last_publish_request: Dictionary = {}
var _last_counterattack_event: Dictionary = {}
var _opponent_pool_exhausted_reported: bool = false
var _configured: bool = false


## 注入 C 的静态内容配置与随机种子；时钟、发表和棋子状态继续由 A/B 拥有。
func configure(content_catalog: Object, seed_value: int = 1) -> bool:
	_configured = false
	_content_catalog = content_catalog
	if content_catalog == null or not content_catalog.has_method("get_opponent_config") \
		or not content_catalog.has_method("get_word_ids"):
		return false
	# A 先用正式 LevelProfile 配置 C；导演读取当前主播参数，不再绑定费米配置。
	_profile = content_catalog.call("get_opponent_config")
	if _profile.is_empty():
		return false
	_level_id = str(_profile.get("level_id", ""))
	_streamer_id = str(_profile.get("streamer_id", ""))
	if _level_id.is_empty() or _streamer_id.is_empty():
		return false
	_rng.seed = seed_value
	_spawn_area = Rect2()
	speech_enabled = bool(_profile.get("speech_enabled", false))
	counterattack_enabled = bool(_profile.get("counterattack_enabled", false))
	_speech_cooldown_remaining = float(_profile.get("initial_speech_delay_seconds", 0.0))
	_counterattack_cooldown_remaining = 0.0
	_windup_remaining = 0.0
	_pending_counterattack.clear()
	_awaiting_counterattack_result = false
	_counterattack_uses = 0
	_counterattack_t2_qualified = false
	_counterattack_t4_qualified = false
	_counterattack_paused = false
	_no_target_result_reported_by_tier.clear()
	_last_publish_request.clear()
	_last_counterattack_event.clear()
	_pending_speech_word_id = ""
	_awaiting_speech_publish_result = false
	_opponent_pool_exhausted_reported = false
	_configured = true
	return true


## A 可注入执行器调用 B 的公开效果入口；C 不直接修改棋子。
func set_counterattack_effect_handler(handler: Callable) -> void:
	_counterattack_effect_handler = handler


## PB-25 在正式教程状态内暂缓反击计时；Tier资格仍会在update时记录。
func set_counterattack_paused(paused: bool) -> bool:
	if not _configured:
		return false
	_counterattack_paused = paused
	return true


## 教学专用入口仍复用当前主播技能、正式效果处理器与结果回执；仅跳过Tier资格/领先人数门槛。
func request_tutorial_counterattack(
	round_number: int,
	opponent_unit_snapshots: Array[Dictionary],
	current_tier: int
) -> bool:
	if (not _configured or not counterattack_enabled
			or not bool(_profile.get("counterattack_enabled", false))
			or _counterattack_paused or not _pending_counterattack.is_empty()
			or _awaiting_counterattack_result or round_number not in [1, 2]
			or _counterattack_uses >= int(_profile.get("counterattack_max_uses", 0))):
		return false
	var opponent_unit_ids := _get_unit_ids_for_team(opponent_unit_snapshots, "opponent")
	if opponent_unit_ids.is_empty():
		return false
	var skill_id := str(_profile.get("counterattack_skill_id", ""))
	var effect_id := StringName(str(_profile.get("counterattack_effect_id", "")))
	if skill_id.is_empty() or str(effect_id).is_empty():
		return false
	var skill_mapping := _get_skill_mapping(skill_id)
	var request := {
		"counterattack_round": round_number,
		"qualification_tier": 2 if round_number == 1 else 4,
		"current_tier": current_tier,
		"streamer_id": _streamer_id,
		"skill_id": skill_id,
		"skill_name_cn": _get_counterattack_skill_name_cn(skill_id, skill_mapping),
		"trigger_event": "tutorial_scripted_counterattack",
		"target_unit_id": opponent_unit_ids[_rng.randi_range(0, opponent_unit_ids.size() - 1)],
		"effect_id": effect_id,
		"effect_parameters": {
			"child_count": int(_profile.get("counterattack_child_count", 0)),
			"max_targets": 3,
			"radius_pixels": 120.0,
		},
		"pre_windup_seconds": float(_profile.get("counterattack_pre_windup_seconds", 0.0)),
		"cooldown_seconds": float(_profile.get("counterattack_cooldown_seconds", 0.0)),
	}
	_pending_counterattack = request
	_windup_remaining = float(request["pre_windup_seconds"])
	_last_counterattack_event = request.duplicate(true)
	counterattack_windup_started.emit(request.duplicate(true))
	if _windup_remaining <= 0.0:
		_request_counterattack_effect()
	return true


## A 在战斗开始时传入 B 使用的棋盘范围；C 只在范围内选择批次落点。
func set_spawn_area(spawn_area: Rect2) -> bool:
	if not spawn_area.has_area() or spawn_area.size.x <= SPAWN_MARGIN_PIXELS * 2.0 \
		or spawn_area.size.y <= SPAWN_MARGIN_PIXELS * 2.0:
		_spawn_area = Rect2()
		return false
	_spawn_area = spawn_area
	return true


## A 每帧传入 B 的快照与自身可发表词 ID；C 选择词句和坐标，发表结果仍由 A 裁决。
func update_speech(
	delta: float,
	neutral_unit_snapshots: Array[Dictionary],
	available_opponent_word_ids: Array[String]
) -> void:
	if not _configured or not speech_enabled or _awaiting_speech_publish_result:
		return
	var word_ids: Array[String] = _get_publishable_opponent_word_ids(available_opponent_word_ids)
	if word_ids.is_empty():
		_report_opponent_pool_exhausted()
		return
	_speech_cooldown_remaining = maxf(0.0, _speech_cooldown_remaining - maxf(0.0, delta))
	if _speech_cooldown_remaining > 0.0:
		return

	var spawn_position: Variant = _choose_spawn_position(neutral_unit_snapshots)
	if not spawn_position is Vector2:
		return

	var word_id: String = word_ids[_rng.randi_range(0, word_ids.size() - 1)]
	_pending_speech_word_id = word_id
	_awaiting_speech_publish_result = true
	_last_publish_request = {"word_id": word_id, "spawn_position": spawn_position}
	# A 将坐标请求送入双方共用的整批 publish_word；成功事实回来后才启动对手冷却。
	publish_word_requested.emit(word_id, spawn_position)


## A 回报整批发表结果；失败保留词与冷却，成功才开始发言间隔。
func report_speech_publish_result(word_id: String, published: bool) -> bool:
	if not _configured or not _awaiting_speech_publish_result or word_id != _pending_speech_word_id:
		return false
	if published:
		_speech_cooldown_remaining = float(_profile.get("speech_cooldown_seconds", 11.5))
	_pending_speech_word_id = ""
	_awaiting_speech_publish_result = false
	return true


## A 每帧传入双方人数与 B 的对手棋子快照，控制器只发出反击请求事件。
func update_counterattack(
	delta: float,
	faction_counts: Dictionary,
	opponent_unit_snapshots: Array[Dictionary],
	current_tier: int
) -> void:
	if not _configured:
		return
	# 只读正式Tier编号；Tier Catalog决定64%/79%边界，回落不会撤销已取得的轮次。
	if current_tier >= 2:
		_counterattack_t2_qualified = true
	if current_tier >= 4:
		_counterattack_t4_qualified = true
	if not counterattack_enabled or not bool(_profile.get("counterattack_enabled", false)):
		return
	if _counterattack_uses >= int(_profile.get("counterattack_max_uses", 0)):
		return
	if _counterattack_paused:
		return

	var elapsed: float = maxf(0.0, delta)
	_counterattack_cooldown_remaining = maxf(0.0, _counterattack_cooldown_remaining - elapsed)
	if not _pending_counterattack.is_empty():
		if _awaiting_counterattack_result:
			return
		var pending_player_count: int = int(faction_counts.get("player", 0))
		var pending_opponent_count: int = int(faction_counts.get("opponent", 0))
		var pending_lead_margin: int = int(_profile.get("counterattack_lead_margin", 0))
		if pending_player_count - pending_opponent_count < pending_lead_margin:
			_resolve_pending_without_effect("player_lead_lost")
			return
		var target_unit_id: String = str(_pending_counterattack.get("target_unit_id", ""))
		if not _get_unit_ids_for_team(opponent_unit_snapshots, "opponent").has(target_unit_id):
			_resolve_pending_without_effect("target_unavailable")
			return
		_windup_remaining = maxf(0.0, _windup_remaining - elapsed)
		if _windup_remaining <= 0.0:
			_request_counterattack_effect()
		return
	if _counterattack_cooldown_remaining > 0.0:
		return
	var round_tier: int = _get_next_counterattack_round_tier()
	if round_tier <= 0:
		return

	var player_count: int = int(faction_counts.get("player", 0))
	var opponent_count: int = int(faction_counts.get("opponent", 0))
	var lead_margin: int = int(_profile.get("counterattack_lead_margin", 0))
	if player_count - opponent_count < lead_margin:
		return
	var opponent_unit_ids: Array[String] = _get_unit_ids_for_team(opponent_unit_snapshots, "opponent")
	var skill_id: String = str(_profile.get("counterattack_skill_id", ""))
	if skill_id.is_empty():
		_emit_counterattack_preflight_failure(round_tier, "missing_skill_id", "")
		return
	var skill_mapping: Dictionary = _get_skill_mapping(skill_id)
	var skill_name_cn: String = _get_counterattack_skill_name_cn(skill_id, skill_mapping)
	var request := {
		"counterattack_round": 1 if round_tier == 2 else 2,
		"qualification_tier": round_tier,
		"current_tier": current_tier,
		"streamer_id": _streamer_id,
		"skill_id": skill_id,
		"skill_name_cn": skill_name_cn,
		"trigger_event": str(_profile.get("counterattack_trigger_event", "tier_2_tier_4")),
		"target_unit_id": "",
		"effect_id": StringName(str(_profile.get("counterattack_effect_id", ""))),
		"effect_parameters": {
			"child_count": int(_profile.get("counterattack_child_count", 0)),
			"max_targets": 3,
			"radius_pixels": 120.0,
		},
		"pre_windup_seconds": float(_profile.get("counterattack_pre_windup_seconds", 0.0)),
		"cooldown_seconds": float(_profile.get("counterattack_cooldown_seconds", 0.0)),
	}
	if String(request["effect_id"]).is_empty():
		_emit_counterattack_preflight_failure(round_tier, "missing_effect_id", skill_id, request)
		return
	if opponent_unit_ids.is_empty():
		_emit_counterattack_preflight_failure(round_tier, "no_usable_target", skill_id, request)
		return
	request["target_unit_id"] = opponent_unit_ids[_rng.randi_range(0, opponent_unit_ids.size() - 1)]
	_pending_counterattack = request
	_windup_remaining = float(request["pre_windup_seconds"])
	_last_counterattack_event = request.duplicate(true)
	# D 可在此事件后显示前摇提示；效果到时仍交由 A 调用 B 的公开接口。
	counterattack_windup_started.emit(request.duplicate(true))
	if _windup_remaining <= 0.0:
		_request_counterattack_effect()


## A/B 完成效果后回报结果；本模块据此更新尝试次数和冷却，不改棋子状态。
func report_counterattack_result(effect_result: Variant) -> bool:
	if not _configured or _pending_counterattack.is_empty() or not _awaiting_counterattack_result:
		return false
	var result: Dictionary = _pending_counterattack.duplicate(true)
	var effect_details: Dictionary = {}
	var applied: bool = false
	if effect_result is Dictionary:
		effect_details = effect_result.duplicate(true)
		applied = bool(effect_details.get("ok", effect_details.get("applied", false)))
	elif effect_result is bool:
		applied = bool(effect_result)
	for detail_key: Variant in effect_details:
		if str(detail_key) not in ["ok", "applied"]:
			result[str(detail_key)] = effect_details[detail_key]
	result["applied"] = applied
	if applied:
		_counterattack_uses += 1
		_counterattack_cooldown_remaining = float(_pending_counterattack.get("cooldown_seconds", 0.0))
		result["result_reason"] = str(effect_details.get("result_reason", effect_details.get("reason", "applied")))
		if not result.has("message"):
			result["message"] = "反击已生效"
	else:
		var failure_reason: String = str(effect_details.get("result_reason", effect_details.get("reason", "effect_not_applied")))
		result["result_reason"] = failure_reason
		if not result.has("message"):
			result["message"] = _counterattack_result_message(failure_reason)
		var failed_round_tier: int = int(result.get("qualification_tier", 0))
		if failed_round_tier > 0:
			_no_target_result_reported_by_tier[failed_round_tier] = true
	_pending_counterattack.clear()
	_awaiting_counterattack_result = false
	_windup_remaining = 0.0
	_last_counterattack_event = result.duplicate(true)
	counterattack_resolved.emit(result)
	return true


## 提供调试用值副本，便于 A/D 观察冷却、请求和反击阶段。
func get_debug_snapshot() -> Dictionary:
	return {
		"configured": _configured,
		"level_id": _level_id,
		"streamer_id": _streamer_id,
		"speech_enabled": speech_enabled,
		"speech_cooldown_remaining": _speech_cooldown_remaining,
		"pending_speech_word_id": _pending_speech_word_id,
		"awaiting_speech_publish_result": _awaiting_speech_publish_result,
		"spawn_area": _spawn_area,
		"last_publish_request": _last_publish_request.duplicate(true),
		"counterattack_enabled": counterattack_enabled,
		"counterattack_paused": _counterattack_paused,
		"counterattack_cooldown_remaining": _counterattack_cooldown_remaining,
		"counterattack_windup_remaining": _windup_remaining,
		"counterattack_uses": _counterattack_uses,
		"counterattack_t2_qualified": _counterattack_t2_qualified,
		"counterattack_t4_qualified": _counterattack_t4_qualified,
		"pending_counterattack": _pending_counterattack.duplicate(true),
		"last_counterattack_event": _last_counterattack_event.duplicate(true),
		"opponent_word_pool_exhausted_reported": _opponent_pool_exhausted_reported,
	}


func _get_publishable_opponent_word_ids(available_ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var configured_ids: Array = _content_catalog.call("get_word_ids", _level_id, "opponent")
	for word_id_value: Variant in configured_ids:
		var word_id: String = str(word_id_value)
		if not available_ids.has(word_id):
			continue
		var definition: Dictionary = _content_catalog.call("get_word_definition", word_id)
		if str(definition.get("available_level", "")) == _level_id \
			and str(definition.get("available_to", "")) == "opponent" \
			and str(definition.get("streamer_id", "")) == _streamer_id:
			result.append(word_id)
	return result


func _report_opponent_pool_exhausted() -> void:
	# A 收到一次耗尽事件后继续推进流程；避免逐帧重复通知。
	if _opponent_pool_exhausted_reported:
		return
	_opponent_pool_exhausted_reported = true
	opponent_word_pool_exhausted.emit(_level_id, _streamer_id)


func _choose_spawn_position(neutral_snapshots: Array[Dictionary]) -> Variant:
	if _spawn_area.has_area():
		var min_x: float = _spawn_area.position.x + SPAWN_MARGIN_PIXELS
		var max_x: float = _spawn_area.position.x + _spawn_area.size.x - SPAWN_MARGIN_PIXELS
		var min_y: float = _spawn_area.position.y + SPAWN_MARGIN_PIXELS
		var max_y: float = _spawn_area.position.y + _spawn_area.size.y - SPAWN_MARGIN_PIXELS
		return Vector2(_rng.randf_range(min_x, max_x), _rng.randf_range(min_y, max_y))

	# 兼容旧 A 调用：范围尚未注入时，只复用已有中立单位坐标，不传递其 unit_id。
	var candidate_positions: Array[Vector2] = []
	for snapshot: Dictionary in neutral_snapshots:
		if str(snapshot.get("team", "")) != "neutral":
			continue
		var position: Variant = snapshot.get("position", null)
		if position is Vector2:
			candidate_positions.append(position)
	if candidate_positions.is_empty():
		return null
	return candidate_positions[_rng.randi_range(0, candidate_positions.size() - 1)]


func _get_unit_ids_for_team(snapshots: Array[Dictionary], team: String) -> Array[String]:
	var result: Array[String] = []
	for snapshot: Dictionary in snapshots:
		if str(snapshot.get("team", "")) != team:
			continue
		var unit_id: String = str(snapshot.get("unit_id", ""))
		if not unit_id.is_empty():
			result.append(unit_id)
	return result


## 先消费已获得的T2轮次，再允许进入T4轮次；成功次数就是唯一消耗状态。
func _get_next_counterattack_round_tier() -> int:
	if _counterattack_uses == 0 and _counterattack_t2_qualified:
		return 2
	if _counterattack_uses == 1 and _counterattack_t4_qualified:
		return 4
	return 0


## 反击请求沿用当前主播配置的技能ID，并从21表映射取中文显示名。
func _get_skill_mapping(skill_id: String) -> Dictionary:
	if _content_catalog == null or not _content_catalog.has_method("get_retaliation_skill_mappings"):
		return {}
	var mappings_value: Variant = _content_catalog.call("get_retaliation_skill_mappings", _streamer_id)
	if not mappings_value is Array:
		return {}
	for mapping_value: Variant in mappings_value:
		if not mapping_value is Dictionary:
			continue
		var mapping: Dictionary = mapping_value
		if str(mapping.get("skill_id", "")) == skill_id:
			return mapping.duplicate(true)
	return {}


## PB-27 的正式主播专属技能名优先于临时21表trait名。
func _get_counterattack_skill_name_cn(skill_id: String, mapping: Dictionary) -> String:
	var fixed_name: String = str(COUNTERATTACK_SKILL_NAMES_ZH.get(_streamer_id, ""))
	if not fixed_name.is_empty():
		return fixed_name
	return str(mapping.get("trait_name", "特殊反击"))


## 候选缺少配置或目标时回报一次明确失败，保留当前轮次等待后续有效状态。
func _emit_counterattack_preflight_failure(
	round_tier: int,
	reason: String,
	skill_id: String,
	event_data: Dictionary = {}
) -> void:
	if bool(_no_target_result_reported_by_tier.get(round_tier, false)):
		return
	_no_target_result_reported_by_tier[round_tier] = true
	var result: Dictionary = event_data.duplicate(true)
	if result.is_empty():
		result = {
			"counterattack_round": 1 if round_tier == 2 else 2,
			"qualification_tier": round_tier,
			"streamer_id": _streamer_id,
			"skill_id": skill_id,
			"skill_name_cn": _get_counterattack_skill_name_cn(skill_id, _get_skill_mapping(skill_id)),
			"trigger_event": str(_profile.get("counterattack_trigger_event", "tier_2_tier_4")),
			"target_unit_id": "",
		}
	result["applied"] = false
	result["result_reason"] = reason
	result["message"] = _counterattack_result_message(reason)
	_last_counterattack_event = result.duplicate(true)
	counterattack_resolved.emit(result)


## 前摇期间领先或目标消失时结束当前提示；对应轮次仍可在条件恢复后执行。
func _resolve_pending_without_effect(reason: String) -> void:
	if _pending_counterattack.is_empty():
		return
	var result: Dictionary = _pending_counterattack.duplicate(true)
	result["applied"] = false
	result["result_reason"] = reason
	result["message"] = _counterattack_result_message(reason)
	var round_tier: int = int(result.get("qualification_tier", 0))
	_pending_counterattack.clear()
	_awaiting_counterattack_result = false
	_windup_remaining = 0.0
	if round_tier > 0:
		_no_target_result_reported_by_tier[round_tier] = true
	_last_counterattack_event = result.duplicate(true)
	counterattack_resolved.emit(result)


## 给PB-27 /表现层提供明确失败事实，同时保留稳定机器可读原因码。
func _counterattack_result_message(reason: String) -> String:
	match reason:
		"no_usable_target":
			return "没有可用反击目标"
		"missing_skill_id", "missing_effect_id":
			return "反击技能配置缺失"
		"player_lead_lost":
			return "发动前玩家领先人数不足"
		"target_unavailable":
			return "反击目标已离场"
		"effect_not_applied":
			return "反击效果未生效"
		_:
			return "反击未生效"


func _request_counterattack_effect() -> void:
	_awaiting_counterattack_result = true
	_last_counterattack_event = _pending_counterattack.duplicate(true)
	var request: Dictionary = _pending_counterattack.duplicate(true)
	if _counterattack_effect_handler.is_valid():
		# 执行入口由 A 注入并转接 B；结果携带成功状态、实际目标和效果数量。
		report_counterattack_result(_counterattack_effect_handler.call(request))
	else:
		counterattack_effect_requested.emit(request)
