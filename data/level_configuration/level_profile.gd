## 保存一关静态基础信息和展示引用，不包含关卡运行时状态。
class_name LevelProfile
extends Resource

## 稳定关卡 ID，用于跨系统区分关卡。
@export var level_id: String = ""
@export var level_order: int = 1

## 主播稳定 ID 用于关联系统数据，名称用于展示。
@export var streamer_id: String = ""
@export var streamer_name: String = ""
## 关卡表中可供立绘、教学与剧情系统稳定关联的配置 ID。
@export var portrait_set_id: String = ""
@export var tutorial_config_id: String = ""
@export var story_config_id: String = ""
@export var contradiction_set_id: String = ""
@export var background_asset_id: String = ""
@export var fan_badge_asset_id: String = ""
## 关卡正式数据中的并吞奖励；disabled 行保留为空数组以供审计。
@export var assimilation_reward_ids: Array[String] = []
@export var assimilation_content_ids: Array[String] = []
@export var assimilation_inherited_weights: Array[float] = []
@export var assimilation_rewards: Array[Dictionary] = []
## 对手主播的粉丝团显示名；正式导表映射待关卡数据工具确认后接入。
@export var fan_group_name: String = ""
@export var streamer_portrait: Texture2D
@export var opponent_tier_01_portrait: Texture2D
@export var opponent_tier_02_portrait: Texture2D
@export var opponent_tier_03_portrait: Texture2D
@export var opponent_defeat_portrait: Texture2D
@export var opponent_defeat_transition_portrait: Texture2D
@export var streamer_avatar: Texture2D
@export var streamer_live_background: Texture2D
## 关卡直播前景与击败演出稳定 ID；由表现 Owner 消费，不在数据层播放。
@export var streamer_live_foreground: Texture2D
@export var opponent_defeat_effect_id: StringName = &""
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
## 本关携带特性实例同屏上限；-1 表示暂沿用当前普通前景上限。
@export var special_instance_screen_cap: int = -1

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
@export var word_weight_multiplier: float = 1.0
@export var valid_area_key: String = ""
@export var layout_key: String = ""

## 当前关卡的 Paradox 设计参数；消费逻辑仍由矛盾系统负责。
@export var paradox_window_seconds: float = 10.0
@export var paradox_shot_limit: int = 1
@export var paradox_silence_transition_seconds: float = 1.0
@export var paradox_candidate_count: int = 6
@export var paradox_true_count: int = 1
@export var paradox_fake_count: int = 5
@export var paradox_motion_duration_seconds: float = 2.0
@export var paradox_motion_mode: String = ""
@export var paradox_shootable_during_motion: bool = true
@export var paradox_motion_speed_curve_id: String = ""
