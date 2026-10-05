class_name IdentityNameRules
extends RefCounted

const DEFAULT_STREAMER_NAME: String = "新主播"

# 空字符串和纯空白都回退到默认名；有内容时原样保留玩家输入。
static func confirm_streamer_name(input_name: String) -> String:
	if input_name.strip_edges().is_empty():
		return DEFAULT_STREAMER_NAME
	return input_name
