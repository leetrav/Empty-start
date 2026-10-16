## 组合正式特性目录与既有弹幕生成器；不拥有 PK、Tier、存档或生成 Timer。
class_name BarrageTraitRuntime
extends RefCounted

signal counter_skill_spawned(skill_id: String, tier: int, view: BarrageView)
signal split_children_spawned(parent_id: int, children: Array[BarrageView], requested_count: int)
signal visual_asset_requested(view: BarrageView, asset_id: String, status: Dictionary)

var _area: BarrageArea
var _catalog: BarrageTraitCatalog
var _level_profile: LevelProfile


## 在普通生成启动前绑定；重复绑定先解除旧连接，重开可复用同一对象。
func bind(area: BarrageArea, catalog: BarrageTraitCatalog) -> bool:
	if area == null or catalog == null:
		return false
	unbind()
	_area = area
	_catalog = catalog
	_area.configure_trait_catalog(catalog)
	_area.barrage_generated.connect(_on_barrage_generated)
	return true


## 场景释放前显式解除连接，不清空其他系统持有的状态。
func unbind() -> void:
	if is_instance_valid(_area) and _area.barrage_generated.is_connected(_on_barrage_generated):
		_area.barrage_generated.disconnect(_on_barrage_generated)
	_area = null
	_catalog = null
	_level_profile = null


## 每次开始或重开交入真实关卡，子体继续使用相同容量与移动配置。
func begin_attempt(profile: LevelProfile) -> void:
	_level_profile = profile


## A 在普通批次或升档后的生成时机调用；容量失败不发布实际生成事实。
func spawn_counter_skill(profile: LevelProfile, speech: LevelSpeech, tier: int, rng: RandomNumberGenerator = null) -> BarrageView:
	if _catalog == null or profile == null:
		return null
	return spawn_skill(profile, speech, _catalog.choose_skill(profile.streamer_id, tier, rng))


## 显式技能同样校验 21 正式启用集合，可供剧情指定或逐项运行验收。
func spawn_skill(profile: LevelProfile, speech: LevelSpeech, skill: Dictionary) -> BarrageView:
	if not is_instance_valid(_area) or _catalog == null or profile == null or speech == null:
		return null
	var selected: Dictionary = {}
	for candidate: Dictionary in _catalog.get_enabled_skills(profile.streamer_id, int(skill.get("tier", -1))):
		if candidate.get("skill_id") == skill.get("skill_id"):
			selected = candidate
			break
	if selected.is_empty():
		return null
	_level_profile = profile
	var traits: Array[StringName] = _catalog.get_skill_trait_ids(selected)
	if traits.is_empty():
		return null
	var view: BarrageView = _spawn_with_traits(profile, speech, traits)
	if view != null:
		counter_skill_spawned.emit(str(selected.get("skill_id", "")), int(selected.get("tier", -1)), view)
	return view


## 21 是本次技能的可用来源；只扩展单次生成配置副本，原关卡 Resource 保持只读。
func _spawn_with_traits(profile: LevelProfile, speech: LevelSpeech, traits: Array[StringName]) -> BarrageView:
	var spawn_profile := profile.duplicate() as LevelProfile
	spawn_profile.special_trait_ids = profile.special_trait_ids.duplicate()
	for trait_id: StringName in traits:
		if not spawn_profile.special_trait_ids.has(String(trait_id)):
			spawn_profile.special_trait_ids.append(String(trait_id))
	return _area.spawn_normal_barrage(spawn_profile, speech, traits)


## 实际生成时捕获 07 规则；沿用首个寿命覆盖，分裂稍后继承母体截止。
func _on_barrage_generated(view: BarrageView) -> void:
	var facts: BarrageRuntimeRecord = view.runtime_record
	if facts == null or facts.is_repeat or facts.is_contradiction:
		return
	_catalog.configure_trait_set(facts.trait_set)
	# 弹幕寿命由 BarrageArea 按 07 覆盖和 06 Tier 规则唯一计算，后续表现不重置截止时间。
	for trait_id: StringName in facts.trait_set.get_trait_ids():
		var status: Dictionary = _catalog.get_visual_asset_status(trait_id)
		visual_asset_requested.emit(view, str(status.get("visual_asset_id", "")), status)


## 使用同一普通原句创建反击复制品；复制品与复读均不能继续复制。
func spawn_retaliation_copy(source: BarrageView, profile: LevelProfile) -> BarrageView:
	if not is_instance_valid(source) or source.runtime_record == null or not is_instance_valid(_area) or profile == null:
		return null
	var facts: BarrageRuntimeRecord = source.runtime_record
	if (facts.is_repeat or facts.is_contradiction or facts.expires_at_msec <= Time.get_ticks_msec()
			or not facts.trait_set.can_trigger_copy() or not facts.trait_set.get_hit_result().receives_normal_reward):
		return null
	var traits: Array[StringName] = [BarrageTraitSet.RETALIATION_COPY]
	return _spawn_with_traits(profile, _speech_from_record(facts), traits)


## 接 BattleAttemptFlow.shot_resolved：它已结算并释放原目标容量，子体不会挤掉母体收益。
func on_shot_resolved(_snapshot: AttackTargetSnapshot, submission: Dictionary, _tier: int, _stats: RepeatGenerationStats) -> void:
	var result: Dictionary = submission.get("hit_resolution_result", {})
	if bool(result.get("cancelled_by_zero_pk", false)) or bool(result.get("terminal_mode", false)):
		return
	for target_result: Dictionary in result.get("target_results", []):
		if not bool(target_result.get("is_valid_hit", false)) or bool(target_result.get("is_repeat", false)):
			continue
		var target_id: int = int(target_result.get("target_instance_id", 0))
		if target_id <= 0:
			continue
		var source := instance_from_id(target_id) as BarrageView
		if is_instance_valid(source):
			split_on_normal_hit(source)


## 母体只分裂一次；所有子片保留同原句与绝对截止，容量不足时仅返回实际成功部分。
func split_on_normal_hit(source: BarrageView) -> Array[BarrageView]:
	var children: Array[BarrageView] = []
	if not is_instance_valid(source) or source.runtime_record == null or not is_instance_valid(_area) or _level_profile == null:
		return children
	var facts: BarrageRuntimeRecord = source.runtime_record
	if not facts.trait_set.try_begin_split(not facts.is_repeat and not facts.is_contradiction):
		return children
	var requested: int = facts.trait_set.get_split_child_count()
	var position: Vector2 = source.position
	# 已完成 flow 清理时此调用安全返回 false；单独使用时先释放母体名额。
	_area.end_barrage(source.get_instance_id())
	if facts.expires_at_msec <= Time.get_ticks_msec():
		return children
	for index: int in requested:
		var child: BarrageView = _spawn_with_traits(_level_profile, _speech_from_record(facts), facts.trait_set.get_trait_ids())
		if child == null:
			break
		child.runtime_record.expires_at_msec = facts.expires_at_msec
		child.runtime_record.lifetime_duration_msec = facts.lifetime_duration_msec
		child.runtime_record.trait_set.try_begin_split(true)
		child.position = (position + Vector2(float(index) * 18.0, float(index) * 12.0)).clamp(Vector2.ZERO, (_area.size - child.size).max(Vector2.ZERO))
		children.append(child)
	split_children_spawned.emit(source.get_instance_id(), children, requested)
	return children


## 子体复用原句身份与强度，不建立第二份命中历史。
func _speech_from_record(facts: BarrageRuntimeRecord) -> LevelSpeech:
	var speech := LevelSpeech.new()
	speech.original_sentence_id = facts.original_sentence_id
	speech.text = facts.original_sentence_text
	speech.tendency_id = facts.tendency_id
	speech.strength = clampi(int(facts.strength), 1, 3)
	return speech
