class_name IdentityNameRules
extends RefCounted

const DEFAULT_STREAMER_NAME: String = "新主播"
const DEFAULT_FAN_GROUP_NAME: String = "新粉丝团"

# 主播名和粉丝团名共享空白判定与输入保留规则，由调用方传入各自默认值。
static func confirm_name(input_name: String, default_name: String) -> String:
	if input_name.strip_edges().is_empty():
		return default_name
	return input_name


# 确认主播名；空白回退到身份系统配置的默认主播名。
static func confirm_streamer_name(input_name: String) -> String:
	return confirm_name(input_name, DEFAULT_STREAMER_NAME)


# 确认粉丝团名；空白回退到身份系统配置的默认粉丝团名。
static func confirm_fan_group_name(input_name: String) -> String:
	return confirm_name(input_name, DEFAULT_FAN_GROUP_NAME)
