class_name LoserCardCatalog
extends Resource

@export var profiles: Array[LoserCardProfile] = []


# 用稳定主播 ID 查找静态卡片资料；未配置的主播返回 null。
func find_profile(streamer_id: StringName) -> LoserCardProfile:
	if streamer_id.is_empty():
		return null
	for profile in profiles:
		if profile != null and profile.streamer_id == streamer_id:
			return profile
	return null
