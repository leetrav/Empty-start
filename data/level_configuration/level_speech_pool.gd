## 按 pool_id 聚合从策划表导出的 LevelSpeech；只读静态配置。
class_name LevelSpeechPool
extends Resource

@export var pool_id: String = ""
@export var speeches: Array[LevelSpeech] = []
