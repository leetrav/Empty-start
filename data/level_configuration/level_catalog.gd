## 保存本周目的普通关卡集合；各关的 level_order 是流程顺序来源。
class_name LevelCatalog
extends Resource

@export var profiles: Array[LevelProfile] = []


# 为后续普通关读取已提交吞并内容；资格和去重仍由 14 的登记入口负责。
func get_inherited_content_snapshot(assimilation_data: AssimilationData) -> Dictionary:
	var word_pools: Array[Dictionary] = []
	var trait_ids: Array[StringName] = []
	var result: Dictionary = {"inherited_word_pools": word_pools, "inherited_trait_ids": trait_ids}
	if assimilation_data == null:
		return result
	var committed: Dictionary = assimilation_data.get_current_content_snapshot()
	result["inherited_trait_ids"] = committed["inherited_trait_ids"]
	var weights: Dictionary = committed["inherited_word_weights"]
	for saved_pool_id in weights:
		var pool_id: StringName = StringName(str(saved_pool_id))
		for profile: LevelProfile in profiles:
			if profile == null:
				continue
			var inheritance: WordPoolInheritanceConfig = profile.normal_pool_inheritance
			if inheritance == null or inheritance.pool_id != pool_id:
				continue
			# 当前配置只解析允许继承的普通池，不从矛盾列表或禁止继承池取句子。
			if not inheritance.can_inherit or inheritance.is_contradiction_pool:
				continue
			var source: LevelSpeechPool = profile.normal_speech_pool_source
			if source != null and StringName(source.pool_id) != pool_id:
				continue
			var speeches: Array[LevelSpeech] = []
			for speech: LevelSpeech in profile.get_normal_speech_pool():
				if speech != null:
					speeches.append(speech.duplicate(true) as LevelSpeech)
			word_pools.append({
				"pool_id": pool_id,
				"appearance_weight": float(weights[saved_pool_id]),
				"speeches": speeches,
			})
			# 每个已提交 ID 只解析一次，不因目录复用同池而重复返回。
			break
	return result
