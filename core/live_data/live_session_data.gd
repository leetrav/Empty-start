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
