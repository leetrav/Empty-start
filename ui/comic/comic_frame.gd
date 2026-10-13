class_name ComicFrame
extends Resource

# 每格保存累计画面、原图坐标和本格节奏；原素材只读。
@export var textures: Array[Texture2D] = []
@export var positions: PackedVector2Array = PackedVector2Array()
@export var seconds: float = 2.0
@export var reveal_seconds: float = 0.45
@export var motion_offset: Vector2 = Vector2(0, 24)
@export_multiline var text: String = ""
@export var text_position: Vector2 = Vector2(100, 850)
@export var text_size: Vector2 = Vector2(1720, 160)
@export var characters_per_second: float = 20.0
@export var writing_event: StringName = &"comic_write"
