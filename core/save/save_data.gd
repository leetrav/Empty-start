class_name SaveData
extends Resource

const CURRENT_VERSION: int = 1

@export var save_version: int = CURRENT_VERSION
@export var play_time: float = 0.0
@export var current_scene: String = ""
@export var checkpoint_id: String = ""
