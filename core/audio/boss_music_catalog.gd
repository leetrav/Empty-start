class_name BossMusicCatalog
extends RefCounted

## 正式主播主键到音乐配置的最小目录；强引用让资源随导出进入游戏。
const PROFILES: Dictionary = {
	&"alien": preload("res://data/audio/fermi_tier_music.tres"),
	&"kiwi": preload("res://data/audio/augur_tier_music.tres"),
	&"frog": preload("res://data/audio/gula_tier_music.tres"),
	&"fox": preload("res://data/audio/khleb_tier_music.tres"),
}

static func find_profile(streamer_id: StringName) -> TierMusicProfile:
	return PROFILES.get(streamer_id) as TierMusicProfile
