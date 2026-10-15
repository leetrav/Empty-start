class_name AudioEvent
extends Resource

enum AudioType { MUSIC, SFX, UI }

@export var event_id: StringName = &""
@export var audio_type: AudioType = AudioType.SFX
@export var stream: AudioStream
@export var volume_db: float = 0.0
@export_range(0.01, 4.0, 0.01) var pitch_min: float = 1.0
@export_range(0.01, 4.0, 0.01) var pitch_max: float = 1.0
@export var loop: bool = false
@export var transition_group: String = ""
