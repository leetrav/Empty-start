extends Control

@onready var _viewer_value: Label = %ViewerValue
@onready var _like_value: Label = %LikeValue
@onready var _comment_value: Label = %CommentValue
@onready var _fan_value: Label = %FanValue

var _live_session: LiveSessionData = null


func _ready() -> void:
	# HUD 只读取当前周目的直播数据；Resource.changed 通知后刷新显示。
	if SaveManager.data != null:
		_live_session = SaveManager.data.live_session
		if _live_session != null:
			_live_session.changed.connect(_refresh_values)
	_refresh_values()


# 将当前直播数据映射到四个只读数字标签。
func _refresh_values() -> void:
	if _live_session == null:
		_viewer_value.text = "0"
		_like_value.text = "0"
		_comment_value.text = "0"
		_fan_value.text = "0"
		return

	_viewer_value.text = str(_live_session.viewer_count)
	_like_value.text = str(_live_session.like_count)
	_comment_value.text = str(_live_session.comment_count)
	_fan_value.text = str(_live_session.fan_count)
