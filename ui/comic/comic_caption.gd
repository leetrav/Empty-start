class_name ComicCaption
extends Resource

# 剧情占位也走正式文字配置，后续可直接替换台词、区域和出现时间。
@export_enum("speech", "narration", "danmaku") var kind: String = "speech"
@export_multiline var text: String = "【角色台词待定】"
@export var rect: Rect2 = Rect2(1200, 750, 580, 140)
@export var tail: Vector2 = Vector2(-1, -1)
@export var delay: float = 0.55
