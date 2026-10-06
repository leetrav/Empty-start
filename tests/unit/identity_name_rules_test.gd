extends SceneTree

const NAME_RULES = preload("res://core/identity/identity_name_rules.gd")

func _init() -> void:
	if not _test_blank_name_uses_default():
		quit(1)
		return
	if not _test_normal_name_is_preserved():
		quit(1)
		return
	print("通过：主播名和粉丝团名确认两项单元测试")
	quit()

# 两种名称的空字符串和纯空白输入都应返回各自集中配置的默认名。
func _test_blank_name_uses_default() -> bool:
	if NAME_RULES.confirm_streamer_name("") != NAME_RULES.DEFAULT_STREAMER_NAME:
		push_error("空字符串没有回退到默认主播名")
		return false
	if NAME_RULES.confirm_fan_group_name("") != NAME_RULES.DEFAULT_FAN_GROUP_NAME:
		push_error("空字符串没有回退到默认粉丝团名")
		return false
	if NAME_RULES.confirm_streamer_name(" \t\n") != NAME_RULES.DEFAULT_STREAMER_NAME:
		push_error("纯空白输入没有回退到默认主播名")
		return false
	if NAME_RULES.confirm_fan_group_name(" \t\n") != NAME_RULES.DEFAULT_FAN_GROUP_NAME:
		push_error("纯空白输入没有回退到默认粉丝团名")
		return false
	return true

# 有内容的主播名和粉丝团名应逐字保留，确认逻辑不修剪输入。
func _test_normal_name_is_preserved() -> bool:
	var streamer_name: String = "Jackie"
	var fan_group_name: String = "Jackie's Fans"
	if NAME_RULES.confirm_streamer_name(streamer_name) != streamer_name:
		push_error("正常主播名没有按输入保留")
		return false
	if NAME_RULES.confirm_fan_group_name(fan_group_name) != fan_group_name:
		push_error("正常粉丝团名没有按输入保留")
		return false
	return true
