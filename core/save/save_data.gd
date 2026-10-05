class_name SaveData
extends Resource

const CURRENT_VERSION: int = 1

@export var save_version: int = CURRENT_VERSION
@export var play_time: float = 0.0
@export var current_scene: String = ""
@export var checkpoint_id: String = ""

# 新周目尚未完成身份确认时留空；确认后由 SaveManager 一次写入玩家侧身份数据。
@export var streamer_name: String = ""
@export var fan_group_name: String = ""
@export var identity_id: StringName = &""
