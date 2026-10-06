## 矛盾阶段单条文本定义，保留跨弹幕表现共用的原句 ID。
class_name LevelContradiction
extends Resource

## 真假矛盾分别从所属列表识别，文本自身沿用稳定原句 ID。
@export var original_sentence_id: String = ""
@export_multiline var text: String = ""
