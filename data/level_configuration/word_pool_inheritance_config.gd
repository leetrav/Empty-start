## 普通词库的继承元数据；句子继续由所属 LevelProfile.normal_speech_pool 提供。
class_name WordPoolInheritanceConfig
extends Resource

## 稳定词库 ID 与整池继承权重，独立于 LevelSpeech 的单句抽取权重。
@export var pool_id: StringName = &""
@export var appearance_weight: float = 0.0

## 策划明确允许才继承；矛盾专属池即使允许也由吞并登记入口排除。
@export var can_inherit: bool = false
@export var is_contradiction_pool: bool = false
