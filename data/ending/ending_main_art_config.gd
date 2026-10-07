class_name EndingMainArtConfig
extends Resource

## 三类最终倾向对应的教派主图；具体 Texture2D 由策划 / 美术资源配置提供。
@export var orthodox_main_art: Texture2D
@export var heretical_main_art: Texture2D
@export var absurd_main_art: Texture2D


# 按冻结结果中的稳定倾向 ID 读取主图，不在逻辑中硬编码资源路径。
func get_main_art_for_tendency(tendency_id: String) -> Texture2D:
	match tendency_id:
		"orthodox":
			return orthodox_main_art
		"heretical":
			return heretical_main_art
		"absurd":
			return absurd_main_art
		_:
			return null
