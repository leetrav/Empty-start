## 神降临只读取本周目实际吞并总量，快照由终局调用方持有。
class_name DivineDescentAssimilationInput
extends RefCounted


# 进入终局时调用一次；空成果返回同一字段结构，输出与源存档的集合完全分离。
static func build_snapshot(run_data: SaveData) -> Dictionary:
	var trait_ids: Array[StringName] = []
	var snapshot: Dictionary = {
		"inherited_word_weights": {},
		"inherited_trait_ids": trait_ids,
	}
	if run_data == null or run_data.assimilation_data == null:
		return snapshot
	var assimilation_data: AssimilationData = run_data.assimilation_data
	snapshot["inherited_word_weights"] = assimilation_data.inherited_word_weights.duplicate(true)
	snapshot["inherited_trait_ids"] = assimilation_data.inherited_trait_ids.duplicate(true)
	return snapshot
