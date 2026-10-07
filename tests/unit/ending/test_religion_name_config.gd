extends SceneTree

const CONFIG = preload("res://data/ending/ending_religion_name_config.gd")


func _initialize() -> void:
	var config = _make_config()
	if not _test_pure_tendency_mapping(config):
		quit(1)
		return
	if not _test_orthodox_heretical_mixed_mapping(config):
		quit(1)
		return
	if not _test_absurd_orthodox_mixed_mapping(config):
		quit(1)
		return
	print("PASS EN-03: 3 configured religion-name mappings")
	quit(0)


# 纯倾向组合使用主导 / 次要相同的稳定 ID。
func _test_pure_tendency_mapping(config) -> bool:
	if config.get_religion_name("orthodox", "orthodox") != "TEST_ORTHODOX_NAME":
		push_error("EN-03 纯正统组合没有读取配置教名")
		return false
	if not config.has_complete_mapping():
		push_error("EN-03 九个组合配置没有全部覆盖")
		return false
	return true


# 混合组合保留正统主导、异端次要的方向。
func _test_orthodox_heretical_mixed_mapping(config) -> bool:
	if config.get_religion_name("orthodox", "heretical") != "TEST_ORTHODOX_HERETICAL_NAME":
		push_error("EN-03 正统 / 异端混合组合映射错误")
		return false
	if config.get_religion_name("heretical", "orthodox") == "TEST_ORTHODOX_HERETICAL_NAME":
		push_error("EN-03 混合组合错误地丢失主导 / 次要顺序")
		return false
	return true


# 另一种混合组合确认荒谬主导、正统次要读取独立配置。
func _test_absurd_orthodox_mixed_mapping(config) -> bool:
	if config.get_religion_name("absurd", "orthodox") != "TEST_ABSURD_ORTHODOX_NAME":
		push_error("EN-03 荒谬 / 正统混合组合映射错误")
		return false
	return true


func _make_config():
	var config = CONFIG.new()
	config.orthodox_name = "TEST_ORTHODOX_NAME"
	config.heretical_name = "TEST_HERETICAL_NAME"
	config.absurd_name = "TEST_ABSURD_NAME"
	config.orthodox_heretical_name = "TEST_ORTHODOX_HERETICAL_NAME"
	config.orthodox_absurd_name = "TEST_ORTHODOX_ABSURD_NAME"
	config.heretical_orthodox_name = "TEST_HERETICAL_ORTHODOX_NAME"
	config.heretical_absurd_name = "TEST_HERETICAL_ABSURD_NAME"
	config.absurd_orthodox_name = "TEST_ABSURD_ORTHODOX_NAME"
	config.absurd_heretical_name = "TEST_ABSURD_HERETICAL_NAME"
	return config
