## 本关普通话语定义，跨系统沿用稳定原句 ID。
class_name LevelSpeech
extends Resource

## 普通弹幕及其复读等派生内容沿用同一个原句 ID。
@export var original_sentence_id: String = ""
@export_multiline var text: String = ""

## 倾向 ID 沿用身份选项系统的 orthodox / heretical / absurd 稳定字符串。
@export var tendency_id: String = ""

## 同一倾向内的相对出现权重；1.0 暂作等权默认值。
@export var appearance_weight: float = 1.0
