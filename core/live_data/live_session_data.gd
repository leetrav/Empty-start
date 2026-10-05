class_name LiveSessionData
extends Resource

@export var viewer_count: int = 0
@export var like_count: int = 0
@export var comment_count: int = 0
@export var fan_count: int = 0


# 开始一场直播时重置本场表现值，并接收本周目当前粉丝数。
func initialize_session(initial_fan_count: int) -> void:
	viewer_count = 0
	like_count = 0
	comment_count = 0
	fan_count = initial_fan_count


# 使用调用方本次开播抽取的一次倍率设置观看人数，不在这里重复随机抽取。
func set_opening_viewers(multiplier: float) -> int:
	viewer_count = calculate_opening_viewers(fan_count, multiplier)
	return viewer_count


# 粉丝数乘一次开播倍率后截成整数，并将负结果限制为 0。
static func calculate_opening_viewers(current_fan_count: int, multiplier: float) -> int:
	return maxi(0, int(current_fan_count * multiplier))
