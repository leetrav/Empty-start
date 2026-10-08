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
	# 吞并系统公开入口负责总量读取和集合隔离，终局直接持有其独立快照。
	return run_data.assimilation_data.get_current_content_snapshot()
