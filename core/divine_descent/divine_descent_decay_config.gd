## 15 表终局时序配置；衰减、自动复读和收束共用同一正式 Resource。
class_name DivineDescentDecayConfig
extends Resource

@export var new_word_decay_duration_seconds: float = 60.0
@export var auto_repeat_interval_min_seconds: float = 0.15
@export var auto_repeat_interval_max_seconds: float = 0.38
@export var converge_ratio: float = 0.9
@export var final_emphasis_duration_seconds: float = 1.8
