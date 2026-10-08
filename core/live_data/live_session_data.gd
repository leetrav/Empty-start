class_name LiveSessionData
extends Resource

enum BoostEvent { CONTRADICTION_BREAK, ORACLE_CONFIRMATION }

# 四项数值变化时通知读取它们的表现 UI。
@export var viewer_count: int = 0:
	set(value):
		if viewer_count == value:
			return
		viewer_count = value
		emit_changed()

@export var like_count: int = 0:
	set(value):
		if like_count == value:
			return
		like_count = value
		emit_changed()

@export var comment_count: int = 0:
	set(value):
		if comment_count == value:
			return
		comment_count = value
		emit_changed()

@export var fan_count: int = 0:
	set(value):
		if fan_count == value:
			return
		fan_count = value
		emit_changed()

# 随当前周目保存已结算关卡；开播和本场重开都保留这份记录。
@export var settled_fan_level_ids: Array[StringName] = []

# 短时表现只属于本次开播，不随周目存档保存计时或触发记录。
var _triggered_boost_events: Array[int] = []
var _active_boosts: Array[Dictionary] = []


# 由正式 PK 胜利入口提交配置增量，矛盾成败不影响本次结算。
func commit_pk_win_fans(level_id: StringName, fan_gain: int) -> bool:
	if level_id == &"" or fan_gain < 0 or settled_fan_level_ids.has(level_id):
		return false
	# 先标记再更新计数，changed 信号的同步读取或重复提交不会重复加粉。
	settled_fan_level_ids.append(level_id)
	fan_count += fan_gain
	return true


# 开始一场直播时重置本场表现值，并接收本周目当前粉丝数。
func initialize_session(initial_fan_count: int) -> void:
	_triggered_boost_events.clear()
	_active_boosts.clear()
	viewer_count = 0
	like_count = 0
	comment_count = 0
	fan_count = initial_fan_count


# 正式事件各触发一次；冻结本次配置总增量和时长，缺少有效配置时保持原值。
func start_short_boost(event: BoostEvent, viewer_gain: int, like_gain: int, duration_seconds: float) -> bool:
	if _triggered_boost_events.has(event) or duration_seconds <= 0.0 or viewer_gain < 0 or like_gain < 0:
		return false
	if viewer_gain == 0 and like_gain == 0:
		return false
	_triggered_boost_events.append(event)
	_active_boosts.append({
		"duration": duration_seconds,
		"elapsed": 0.0,
		"viewer_gain": viewer_gain,
		"like_gain": like_gain,
		"applied_viewers": 0,
		"applied_likes": 0,
	})
	return true


# 场景传入实际游戏帧时间；按进度补齐整数增量，结束后保留累计值并停止增长。
func advance_short_boosts(delta: float) -> void:
	if delta <= 0.0:
		return
	for index in range(_active_boosts.size() - 1, -1, -1):
		var boost: Dictionary = _active_boosts[index]
		var duration: float = float(boost["duration"])
		var elapsed: float = minf(duration, float(boost["elapsed"]) + delta)
		var progress: float = elapsed / duration
		var viewers: int = int(int(boost["viewer_gain"]) * progress)
		var likes: int = int(int(boost["like_gain"]) * progress)
		var viewer_delta: int = viewers - int(boost["applied_viewers"])
		var like_delta: int = likes - int(boost["applied_likes"])
		boost["elapsed"] = elapsed
		boost["applied_viewers"] = viewers
		boost["applied_likes"] = likes
		if elapsed >= duration:
			_active_boosts.remove_at(index)
		viewer_count = maxi(0, viewer_count + viewer_delta)
		like_count += like_delta


# 只把弹幕系统确认成功生成的实例数量计为评论，待生成请求不提前入账。
func record_generated_comments(actual_generated_count: int) -> void:
	if actual_generated_count <= 0:
		return
	comment_count += actual_generated_count


# 使用调用方本次开播抽取的一次倍率设置观看人数，不在这里重复随机抽取。
func set_opening_viewers(multiplier: float) -> int:
	viewer_count = calculate_opening_viewers(fan_count, multiplier)
	return viewer_count


# 粉丝数乘一次开播倍率后截成整数，并将负结果限制为 0。
static func calculate_opening_viewers(current_fan_count: int, multiplier: float) -> int:
	return maxi(0, int(current_fan_count * multiplier))
