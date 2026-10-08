extends SceneTree

const CANDIDATE_FILTER = preload("res://core/divine_descent/divine_descent_candidate_filter.gd")
const AREA_SCENE = preload("res://systems/barrage_generation/barrage_area.tscn")


# 仅两个 DD-12 单元用例，文本和尺寸均为 TEST_ONLY 内存数据。
func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var grouping_passed: bool = _test_original_id_groups_variants()
	var ui_passed: bool = _test_ui_excluded()
	quit(0 if grouping_passed and ui_passed else 1)


# 不同显示文本仍按原句计数，同文异 ID 留在分母。
func _test_original_id_groups_variants() -> bool:
	var records: Array[BarrageRuntimeRecord] = []
	for display_text: String in ["TEST_ONLY original", "TEST_ONLY repeat!", "TEST_ONLY repeat??"]:
		var barrage_record := BarrageRuntimeRecord.new()
		barrage_record.original_sentence_id = "test-locked"
		barrage_record.text = display_text
		barrage_record.is_repeat = records.size() > 0
		records.append(barrage_record)
	var other_record := BarrageRuntimeRecord.new()
	other_record.original_sentence_id = "test-other"
	other_record.text = records[0].text
	records.append(other_record)
	var passed: bool = is_equal_approx(CANDIDATE_FILTER.calculate_visible_ratio(records, "test-locked"), 0.75)
	passed = passed and CANDIDATE_FILTER.calculate_visible_ratio([], "test-locked") == 0.0
	passed = passed and CANDIDATE_FILTER.calculate_visible_ratio(records, "") == 0.0
	if not passed:
		push_error("FAIL DD-12 original ID groups visible variants")
		return false
	print("PASS DD-12 original ID groups visible variants ratio=0.75")
	return true


# 真实区域的 UI 背景与同文 Label 都不计数；可见筛选直接使用公开入口。
func _test_ui_excluded() -> bool:
	var area: BarrageArea = AREA_SCENE.instantiate() as BarrageArea
	root.add_child(area)
	area.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	area.size = Vector2(400, 200)
	var view := BarrageView.new()
	view.runtime_record = BarrageRuntimeRecord.new()
	view.runtime_record.original_sentence_id = "test-locked"
	view.text = "TEST_ONLY original"
	view.position = Vector2(10, 10)
	area.add_child(view)
	view.set_process(false)
	var decorator := Label.new()
	decorator.text = view.text
	area.add_child(decorator)
	var records: Array[BarrageRuntimeRecord] = area.get_visible_barrage_records()
	var passed: bool = records.size() == 1
	passed = passed and CANDIDATE_FILTER.calculate_visible_ratio(records, "test-locked") == 1.0
	view.hide()
	passed = passed and area.get_visible_barrage_records().is_empty()
	view.show()
	view.position = Vector2(-1000, 10)
	passed = passed and area.get_visible_barrage_records().is_empty()
	view.position = Vector2(10, 10)
	view.queue_free()
	passed = passed and area.get_visible_barrage_records().is_empty()
	area.free()
	if not passed:
		push_error("FAIL DD-12 UI excluded from visible ratio")
		return false
	print("PASS DD-12 UI excluded from visible ratio ratio=1.0")
	return true
