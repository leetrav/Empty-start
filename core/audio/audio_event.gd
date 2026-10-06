class_name AudioEvent
extends Resource

enum AudioType { MUSIC, SFX, UI }

@export var event_id: StringName = &""
@export var audio_type: AudioType = AudioType.SFX
@export var stream: AudioStream
