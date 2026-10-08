class_name LiveSessionData
extends Resource

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
	viewer_count = 0
	like_count = 0
	comment_count = 0
	fan_count = initial_fan_count


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
