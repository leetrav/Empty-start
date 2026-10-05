class_name AudioEventConfig
extends Resource

@export var events: Array[AudioEvent] = []


# 按稳定事件 ID 查找配置；事件集合很小，直接顺序查找保持配置结构简单。
func find_event(event_id: StringName) -> AudioEvent:
	for event in events:
		if event != null and event.event_id == event_id:
			return event
	return null
