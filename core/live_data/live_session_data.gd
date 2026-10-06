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
