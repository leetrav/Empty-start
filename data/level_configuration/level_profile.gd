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
@export var streamer_avatar: Texture2D
@export var streamer_live_background: Texture2D
@export_multiline var stream_topic: String = ""

## 美术资源尚未提供时可先填稳定 ID，Texture2D 字段可直接替换为正式素材。
@export var fan_badge_id: String = ""
@export var fan_badge_texture: Texture2D

## 普通话语池保留原句定义，供弹幕生成系统读取。
@export var normal_speech_pool: Array[LevelSpeech] = []

## 生成式词库入口：与内嵌词库复用同一 LevelSpeech 结构。
## 正式接入时只需更换 Resource；旧关卡未配置时使用 normal_speech_pool。
@export var normal_speech_pool_source: LevelSpeechPool


func get_normal_speech_pool() -> Array[LevelSpeech]:
    # 只读取词库 Resource，不修改共享的静态 LevelProfile。
    if normal_speech_pool_source != null:
        return normal_speech_pool_source.speeches
    return normal_speech_pool


## 该普通词库的继承配置；留空表示未配置奖励，内容仍使用上面的同一词库。
@export var normal_pool_inheritance: WordPoolInheritanceConfig

## 普通话语类别比例只保存配置值；neutral 不计入玩家三项倾向。
@export var orthodox_ratio: float = 0.0
@export var heretical_ratio: float = 0.0
@export var absurd_ratio: float = 0.0
@export var neutral_ratio: float = 0.0

## 特性 ID 的正式取值由弹幕特性系统定义，关卡只保存本关选择的 ID。
@export var special_trait_ids: Array[String] = []

## 真正击败后允许继承的特性白名单，独立于本关启用的特殊玩法列表。
@export var inheritable_trait_ids: Array[StringName] = []

## 矛盾内容与线索归当前关卡配置，判定规则由矛盾击破系统执行。
@export var true_contradictions: Array[LevelContradiction] = []
@export var false_contradictions: Array[LevelContradiction] = []
@export var contradiction_context_clues: Array[String] = []

## 以下为未实测的基础生成默认值，策划试玩后调整。
@export var base_batch_count: int = 3
@export var base_spawn_interval_seconds: float = 1.0
@export var base_move_speed_pixels_per_second: float = 100.0
@export var normal_barrage_screen_cap: int = 24
