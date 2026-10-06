extends SceneTree

func _init() -> void:
	var passed_count: int = 0
	if _test_new_run_starts_at_first_level():
		passed_count += 1
		print("PASS: 新一局默认读取序号最小的关卡。")
	else:
		push_error("FAIL: 新一局未读取序号最小的关卡。")
	if _test_changing_order_reads_selected_level():
		passed_count += 1
		print("PASS: 切换关卡序号后读取对应配置。")
	else:
		push_error("FAIL: 切换关卡序号后未读取对应配置。")
	print("LC-05: %d/2 tests passed." % passed_count)
	quit(0 if passed_count == 2 else 1)

## 构造乱序目录，确认流程状态按关卡序号定位，不依赖数组位置。
func _make_run_state() -> LevelRunState:
	var second_level: LevelProfile = LevelProfile.new()
	second_level.level_id = "level_002"
	second_level.level_order = 2
	var first_level: LevelProfile = LevelProfile.new()
	first_level.level_id = "level_001"
	first_level.level_order = 1
	var catalog: LevelCatalog = LevelCatalog.new()
	var profiles: Array[LevelProfile] = [second_level, first_level]
	catalog.profiles = profiles
	return LevelRunState.new(catalog)

## 新一局从关卡序号最小的配置开始。
func _test_new_run_starts_at_first_level() -> bool:
	var run_state: LevelRunState = _make_run_state()
	var current_level: LevelProfile = run_state.get_current_level_profile()
	return current_level != null and current_level.level_id == "level_001"

## 当前关卡切换到指定序号后，读取对应稳定关卡 ID。
func _test_changing_order_reads_selected_level() -> bool:
	var run_state: LevelRunState = _make_run_state()
	if not run_state.set_current_level_order(2):
		return false
	var current_level: LevelProfile = run_state.get_current_level_profile()
	return current_level != null and current_level.level_id == "level_002"
