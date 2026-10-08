class_name AudioEventConfig
extends Resource

@export var events: Array[AudioEvent] = []

## 音乐状态的统一时长（秒）和压低倍率；玩法调用方只请求状态。
@export_range(0.0, 10.0, 0.01) var music_fade_in_seconds: float = 0.5
@export_range(0.0, 10.0, 0.01) var music_fade_out_seconds: float = 0.5
@export_range(0.0, 10.0, 0.01) var music_cross_fade_seconds: float = 0.75
@export_range(0.0, 10.0, 0.01) var music_duck_seconds: float = 0.2
@export_range(0.0, 10.0, 0.01) var music_restore_seconds: float = 0.3
@export_range(0.0, 10.0, 0.01) var music_silence_seconds: float = 0.25
@export_range(0.0, 1.0, 0.01) var music_duck_volume: float = 0.25


# 按稳定事件 ID 查找配置；事件集合很小，直接顺序查找保持配置结构简单。
func find_event(event_id: StringName) -> AudioEvent:
	for event in events:
		if event != null and event.event_id == event_id:
			return event
	return null
