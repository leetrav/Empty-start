## 本周目当前普通关卡运行状态，静态关卡资料保持只读。
class_name LevelRunState
extends RefCounted

var _catalog: LevelCatalog
var _current_level: LevelProfile

func _init(catalog: LevelCatalog) -> void:
	_catalog = catalog
	_current_level = _find_first_level()

## 返回当前选中的普通关卡配置；空目录时返回 null。
func get_current_level_profile() -> LevelProfile:
	return _current_level

## 按 LevelProfile.level_order 切换当前关卡，非法序号不会改变当前选择。
func set_current_level_order(level_order: int) -> bool:
	var selected_level: LevelProfile = _find_level_by_order(level_order)
	if selected_level == null:
		return false
	_current_level = selected_level
	return true

## 查找序号最小的关卡，作为新一局的第一关。
func _find_first_level() -> LevelProfile:
	if _catalog == null:
		return null
	var first_level: LevelProfile
	for profile in _catalog.profiles:
		if profile == null:
			continue
		if first_level == null or profile.level_order < first_level.level_order:
			first_level = profile
	return first_level

func _find_level_by_order(level_order: int) -> LevelProfile:
	if _catalog == null:
		return null
	for profile in _catalog.profiles:
		if profile != null and profile.level_order == level_order:
			return profile
	return null
