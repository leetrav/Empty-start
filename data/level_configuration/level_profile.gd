## 保存一关静态基础信息和展示引用，不包含关卡运行时状态。
class_name LevelProfile
extends Resource

## 稳定关卡 ID，用于跨系统区分关卡。
@export var level_id: String = ""
@export var level_order: int = 1

## 主播稳定 ID 用于关联系统数据，名称用于展示。
@export var streamer_id: String = ""
@export var streamer_name: String = ""
@export var streamer_portrait: Texture2D
@export_multiline var stream_topic: String = ""

## 美术资源尚未提供时可先填稳定 ID，Texture2D 字段可直接替换为正式素材。
@export var fan_badge_id: String = ""
@export var fan_badge_texture: Texture2D

## 普通话语池保留原句定义，供弹幕生成系统读取。
@export var normal_speech_pool: Array[LevelSpeech] = []

## 三项比例只保存配置值；本类型不抽取话语或累计玩家倾向。
@export var orthodox_ratio: float = 0.0
@export var heretical_ratio: float = 0.0
@export var absurd_ratio: float = 0.0

## 特性 ID 的正式取值由弹幕特性系统定义，关卡只保存本关选择的 ID。
@export var special_trait_ids: Array[String] = []

## 矛盾内容与线索归当前关卡配置，判定规则由矛盾击破系统执行。
@export var true_contradictions: Array[LevelContradiction] = []
@export var false_contradictions: Array[LevelContradiction] = []
@export var contradiction_context_clues: Array[String] = []
