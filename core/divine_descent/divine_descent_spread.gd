class_name DivineDescentSpread
extends Node

signal repeat_generated(original_sentence_id: StringName, view: BarrageView, current_weight: int)
signal sentence_locked(candidate: Dictionary)

var _candidates: Array[Dictionary] = []
var _barrage_area: BarrageArea
var _random_generator: RandomNumberGenerator
var _timer: Timer
var _repeat_lifetime_seconds: float = 0.0
var _display_template: String = ""
var _generation_blocked: bool = false
var _combat_mode: DivineDescentCombatMode
var _locked_candidate: Dictionary = {}


# 原生 Timer 独立于玩家输入推进；全局暂停沿用 SceneTree 的暂停模式。
func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_timer.timeout.connect(_on_generation_timeout)
	add_child(_timer)


# 从冻结来源初始化一个扩散工作池；频率、寿命和模板由组合方读取真实配置后注入。
func start(
		session: DivineDescentSession, barrage_area: BarrageArea, speech_catalog: LevelCatalog,
		interval_seconds: float, repeat_lifetime_seconds: float, display_template: String,
		random_generator: RandomNumberGenerator = null
) -> bool:
	if _timer == null or not _candidates.is_empty() or session == null or not session.is_entered():
		return false
	if not is_instance_valid(barrage_area) or not barrage_area.is_inside_tree():
		return false
	if interval_seconds <= 0.0 or repeat_lifetime_seconds <= 0.0:
		return false
	var frozen: Dictionary = session.get_entry_snapshot()
	var history_candidates: Array[Dictionary] = frozen["history_candidates"]
	var scripture_entries: Array[Dictionary] = frozen["scripture_entries"]
	var base_candidates: Array[Dictionary] = DivineDescentCandidateFilter.calculate_base_weights(history_candidates)
	var candidates: Array[Dictionary] = DivineDescentCandidateFilter.apply_scripture_bonus(base_candidates, scripture_entries)
	if candidates.is_empty() or not _resolve_original_texts(candidates, speech_catalog):
		return false
	_candidates = candidates
	_barrage_area = barrage_area
	_repeat_lifetime_seconds = repeat_lifetime_seconds
	_display_template = display_template
	_random_generator = random_generator if random_generator != null else RandomNumberGenerator.new()
	if random_generator == null:
		_random_generator.randomize()
	_timer.start(interval_seconds)
	_try_lock_after_new_word_decay()
	return true


# 绑定 DD-05 的真实衰减事实；晚绑定已归零的模式时立即读取当前扩散池。
func bind_new_word_decay(combat_mode: DivineDescentCombatMode) -> bool:
	if combat_mode == null:
		return false
	if _combat_mode != null:
		return _combat_mode == combat_mode
	_combat_mode = combat_mode
	_combat_mode.new_word_rate_changed.connect(_on_new_word_rate_changed)
	_try_lock_after_new_word_decay()
	return true


# 锁句后返回首次独立快照，调用方不能修改已经确定的锁句结果。
func get_locked_candidate() -> Dictionary:
	return _locked_candidate.duplicate(true)


# 锁句状态从已保存结果读取，未归零或空候选时仍为 false。
func is_sentence_locked() -> bool:
	return not _locked_candidate.is_empty()


# 只在真实归零时响应；后续重复通知不能覆盖首次结果。
func _on_new_word_rate_changed(_rate_multiplier: float, _progress: float) -> void:
	_try_lock_after_new_word_decay()


# 完成标记使用近似比较，所以还需严格检查新话率为零，避免极小正值提前锁句。
func _try_lock_after_new_word_decay() -> void:
	if _combat_mode == null or is_sentence_locked() or _candidates.is_empty():
		return
	if not _combat_mode.is_new_word_decay_complete() or _combat_mode.get_new_word_rate_multiplier() != 0.0:
		return
	stop()
	_locked_candidate = DivineDescentCandidateFilter.select_highest_weight_candidate(get_current_candidates())
	if is_sentence_locked():
		sentence_locked.emit(get_locked_candidate())


# 每次重新读取当前权重抽一句；生成失败保持权重，下一次 Timer 到期再尝试。
func generate_next_repeat() -> BarrageView:
	if not is_running() or get_tree().paused:
		return null
	if not is_instance_valid(_barrage_area) or not _barrage_area.is_inside_tree():
		stop()
		return null
	var weights := PackedFloat32Array()
	for candidate: Dictionary in _candidates:
		weights.append(float(candidate["weight"]))
	var index: int = _random_generator.rand_weighted(weights)
	var selected: Dictionary = _candidates[index]
	var plan: RepeatPlan = RepeatPlan.create_normal_hit_plan(
		StringName(str(selected["original_sentence_id"])), str(selected["original_sentence_text"]),
		DivineDescentCombatMode.TERMINAL_TIER, 1, _repeat_lifetime_seconds, str(selected["tendency"])
	)
	if not _display_template.is_empty():
		plan.apply_display_template(_display_template)
	var view: BarrageView = _barrage_area.spawn_repeat_barrage(plan)
	_generation_blocked = view == null
	if view == null:
		return null
	# 只有真实生成成功才更新本原句，冻结历史、基础权重和其他候选均保持原值。
	selected["weight"] = int(selected["weight"]) + 1
	repeat_generated.emit(plan.original_line_id, view, int(selected["weight"]))
	return view


# 停止自动扩散但保留当前工作池，供 DD-09 后续读取锁句依据。
func stop() -> void:
	if _timer != null:
		_timer.stop()


# 当前动态权重唯一归本扩散组件；读取副本不能回写工作池。
func get_current_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate: Dictionary in _candidates:
		result.append(candidate.duplicate(true))
	return result


# 计时状态由 Timer 拥有，不另存一份运行开关。
func is_running() -> bool:
	return _timer != null and not _timer.is_stopped()


# 空生成结果可能来自满容量、无位置或未准备好的区域，统一等待下一轮尝试。
func is_generation_blocked() -> bool:
	return _generation_blocked


# 唯一自动触发来源是计时；不订阅攻击、复读命中或弹幕移除事件。
func _on_generation_timeout() -> void:
	generate_next_repeat()


# 命中存档通常只有 ID；从真实静态词库补正文并复制到工作池，不伪造或丢弃候选。
func _resolve_original_texts(candidates: Array[Dictionary], speech_catalog: LevelCatalog) -> bool:
	var texts_by_id: Dictionary = {}
	if speech_catalog != null:
		for profile: LevelProfile in speech_catalog.profiles:
			if profile == null:
				continue
			for speech: LevelSpeech in profile.get_normal_speech_pool():
				if speech != null and not texts_by_id.has(speech.original_sentence_id):
					texts_by_id[speech.original_sentence_id] = speech.text
	for candidate: Dictionary in candidates:
		if not str(candidate.get("original_sentence_text", "")).is_empty():
			continue
		var sentence_id: String = str(candidate["original_sentence_id"])
		var text: String = str(texts_by_id.get(sentence_id, ""))
		if text.is_empty():
			push_warning("DivineDescentSpread: 缺少历史原句正文：%s" % sentence_id)
			return false
		candidate["original_sentence_text"] = text
	return true
