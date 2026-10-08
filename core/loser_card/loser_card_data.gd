class_name LoserCardData
extends Resource

# 两组 ID 按成功发卡顺序一一对应；卡面与文案继续从静态 Catalog 读取。
@export var acquired_streamer_ids: Array[StringName] = []
@export var rewarded_level_ids: Array[StringName] = []


# 击破成功且神谕正式确认后获得对应资料库卡片，同场只提交一次。
func grant_on_true_defeat(
		level_id: StringName, streamer_id: StringName,
		contradiction_broken: bool, oracle_confirmed: bool, catalog: LoserCardCatalog
	) -> bool:
	if level_id.is_empty() or streamer_id.is_empty() or catalog == null:
		return false
	if not contradiction_broken or not oracle_confirmed or catalog.find_profile(streamer_id) == null:
		return false
	if rewarded_level_ids.has(level_id) or acquired_streamer_ids.has(streamer_id):
		return false
	rewarded_level_ids.append(level_id)
	acquired_streamer_ids.append(streamer_id)
	return true


# 按获得顺序返回历史卡片快照；资料缺失时仍保留已获主播 ID。
func get_acquired_cards(catalog: LoserCardCatalog) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	for streamer_id: StringName in acquired_streamer_ids:
		cards.append(_get_card_snapshot(streamer_id, catalog))
	return cards


# 只读取该关成功发出的卡片；未发卡或旧数据缺少对应主播时返回空结果。
func get_new_card_for_level(level_id: StringName, catalog: LoserCardCatalog) -> Dictionary:
	if level_id.is_empty():
		return {}
	var award_index: int = rewarded_level_ids.find(level_id)
	if award_index < 0 or award_index >= acquired_streamer_ids.size():
		return {}
	return _get_card_snapshot(acquired_streamer_ids[award_index], catalog)


# 外部可修改返回的容器与资料副本，静态 Catalog 和周目保存事实保持原值。
func _get_card_snapshot(streamer_id: StringName, catalog: LoserCardCatalog) -> Dictionary:
	var profile: LoserCardProfile = catalog.find_profile(streamer_id) if catalog != null else null
	return {
		"streamer_id": streamer_id,
		"profile": profile.duplicate(true) as LoserCardProfile if profile != null else null,
	}
