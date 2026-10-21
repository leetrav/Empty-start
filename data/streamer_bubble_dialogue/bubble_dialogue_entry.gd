## 单条气泡对白配置，只保存文本与触发信息。
class_name BubbleDialogueEntry
extends Resource

enum SpeakerSide { PLAYER, OPPONENT }
enum Priority { TIMED_IDLE = 0, HIT = 1, PLOT = 2 }

@export var side: SpeakerSide = SpeakerSide.PLAYER
@export_multiline var text: String = ""
## 沿用 LevelSpeech 的稳定原句 ID；状态和闲聊对白可留空。
@export var original_sentence_id: String = ""
@export var event_id: StringName = &""
## 定时对白相对本场 attempt_started 的秒数；其他事件条目保留 0。
@export_range(0.0, 3600.0, 0.1, "or_greater") var trigger_time_seconds: float = 0.0
## 3 秒仅为可调初值，正式时长等待策划试玩确认。
@export_range(0.1, 60.0, 0.1, "or_greater") var display_duration_seconds: float = 3.0
@export var priority: Priority = Priority.HIT
@export_range(0.0, 1000.0, 0.1) var random_weight: float = 1.0

@export var is_random_idle: bool = false

## 保留正式20表的稳定行 ID、触发键和行序；跨侧对白需要按行序串行播放。
@export_storage var dialogue_id: String = ""
@export_storage var trigger_key: String = ""
@export_storage var line_order: int = 0
@export_storage var source_order: int = 0
