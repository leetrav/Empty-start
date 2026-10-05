class_name SaveData
extends Resource

const CURRENT_VERSION: int = 1

@export var save_version: int = CURRENT_VERSION
@export var play_time: float = 0.0
@export var current_scene: String = ""
@export var checkpoint_id: String = ""

# 新周目尚未完成身份确认时留空；确认后由 SaveManager 一次写入玩家侧身份数据。
@export var streamer_name: String = ""
@export var fan_group_name: String = ""
@export var identity_id: StringName = &""

# 直播数据系统持有本场表现状态；随当前周目存档跨场景保留粉丝数。
@export var live_session: LiveSessionData = LiveSessionData.new()

# 吞并系统保存当前周目累计的主播、词库权重和特性成果。
@export var assimilation_data: AssimilationData = AssimilationData.new()

# 圣典系统持有当前周目已保存及待写入的经文记录。
@export var scripture_data: ScriptureData = ScriptureData.new()
