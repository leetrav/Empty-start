## 本关普通话语定义，跨系统沿用稳定原句 ID。
class_name LevelSpeech
extends Resource

## 普通弹幕及其复读等派生内容沿用同一个原句 ID。
@export var original_sentence_id: String = ""
@export_multiline var text: String = ""

## 共享倾向 ID 约定尚未落地，先保留可编辑字符串，不设第二套枚举。
@export var tendency_id: String = ""

## 同一倾向内的相对出现权重；1.0 暂作等权默认值。
@export var appearance_weight: float = 1.0
