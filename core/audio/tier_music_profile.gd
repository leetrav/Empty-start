class_name TierMusicProfile
extends Resource

## 单个主播的音乐映射与节奏参数，事件资源仍由正式17表负责。
@export var streamer_id: StringName = &"alien"
@export var event_ids: Array[StringName] = [&"music_alien_intro", &"music_alien_low", &"music_alien_mid", &"music_alien_high"]
@export_range(0.0, 10.0) var intro_fade_seconds: float = 2.4
# 仅列巴使用原色出场版；空ID表示直接播放既有对白引子。
@export var entrance_event_id: StringName = &""
@export_range(0.0, 10.0) var entrance_fade_seconds: float = 0.25
@export_range(0.0, 10.0) var dialogue_mix_seconds: float = 0.3
@export var overlap_battle: bool = true
# 四Boss均配置T1开屏起曲，保持引子到T2箭头淡出；可选关闭用于兼容旧策略。
@export var hold_intro_through_first_tier: bool = false
@export var tier_groups: Array[int] = [0, 1, 2, 2, 3, 3]
@export_range(1.0, 300.0) var bpm: float = 100.0
@export_range(1, 16) var beats_per_bar: int = 4
@export_range(0.0, 10.0) var downgrade_hold_seconds: float = 2.0
@export_range(0.0, 10.0) var cross_fade_seconds: float = 0.6


# Tier来源由玩法拥有；映射失败不偷偷播放其他Boss的曲目。
func group_for_tier(tier: int) -> int:
	return tier_groups[clampi(tier, 0, tier_groups.size() - 1)]


func bar_seconds() -> float:
	return 60.0 / bpm * beats_per_bar
