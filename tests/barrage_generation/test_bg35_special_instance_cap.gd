extends SceneTree

const BARRAGE_AREA_SCENE := preload("res://systems/barrage_generation/barrage_area.tscn")
const LEVEL_PROFILE_RESOURCE := preload("res://data/level_configuration/level_001.tres")
const SCREENSHOT_PATH := "res://docs/3. BarrageGeneration/evidence/BG35_special_instance_cap.png"


func _initialize() -> void:
	call_deferred("_run_test")


## 用真实 BarrageArea / BarrageView 检查双账本容量和视图离树后的释放。
func _run_test() -> void:
	seed(35035)
	var failures: Array[String] = []
	if DisplayServer.get_name() != "headless":
		_prepare_visual_canvas()
	var area: BarrageArea = BARRAGE_AREA_SCENE.instantiate() as BarrageArea
	if area == null:
		push_error("FAIL BG-35: BarrageArea Scene failed to load")
		quit(1)
		return
	_set_area_rect(area)
	root.add_child(area)
	await process_frame

	var source_profile: LevelProfile = LEVEL_PROFILE_RESOURCE as LevelProfile
	if source_profile == null or source_profile.special_instance_screen_cap != -1:
		failures.append("existing LevelProfile Resource loads with the unset LC-12 fallback")
	var profile: LevelProfile = LevelProfile.new()
	if source_profile != null:
		profile = source_profile.duplicate(true) as LevelProfile
	profile.level_id = "bg35_test_level"
	profile.streamer_id = "bg35_test_streamer"
	profile.base_batch_count = 0
	profile.base_spawn_interval_seconds = 60.0
	profile.normal_barrage_screen_cap = 2
	profile.special_instance_screen_cap = 1
	profile.special_trait_ids = ["fake_card", "retaliation_copy"]
	area.set_foreground_slot_count(2)
	if not area.start_normal_generation(profile):
		failures.append("normal generation starts for the configured level")

	var compatible_traits: Array[StringName] = [
		BarrageTraitSet.FAKE_CARD,
		BarrageTraitSet.RETALIATION_COPY,
	]
	var special_speech: LevelSpeech = _make_speech("bg35_special", "兼容双特性实例：假牌 + 水军反击")
	var ordinary_speech: LevelSpeech = _make_speech("bg35_ordinary", "普通实例仍使用前景名额")
	var special_view: BarrageView = area.spawn_normal_barrage(profile, special_speech, compatible_traits, true)
	var actual_trait_count: int = (
		special_view.runtime_record.trait_set.get_trait_ids().size()
		if special_view != null and special_view.runtime_record != null
		else 0
	)
	var blocked_special: bool = area.spawn_normal_barrage(profile, special_speech, compatible_traits, true) == null
	var ordinary_view: BarrageView = area.spawn_normal_barrage(profile, ordinary_speech, [], true)
	var blocked_by_normal_cap: bool = area.spawn_normal_barrage(profile, ordinary_speech, [], true) == null
	var initial_normal_count: int = int(area.get_current_barrage_counts().get("normal", 0))
	# 仅在 TEST_ONLY 画面中错开放置两条真实视图，便于检查特性实例与普通实例。
	if special_view != null:
		special_view.position = Vector2(96.0, 168.0)
	if ordinary_view != null:
		ordinary_view.position = Vector2(590.0, 460.0)
	if special_view == null or actual_trait_count != 2 or not blocked_special:
		failures.append("special cap 1 permits one two-trait instance and blocks the next")
	if ordinary_view == null or not blocked_by_normal_cap or initial_normal_count != 2:
		failures.append("special instances also consume normal foreground capacity")
	if DisplayServer.get_name() != "headless":
		await _save_visual_evidence(failures)

	var first_special_released: bool = (
		special_view != null and area.end_barrage(special_view.get_instance_id())
	)
	await process_frame
	var replacement_special: BarrageView = area.spawn_normal_barrage(profile, special_speech, compatible_traits, true)
	var replacement_count: int = int(area.get_current_barrage_counts().get("normal", 0))
	var replacement_plain_blocked: bool = area.spawn_normal_barrage(profile, ordinary_speech, [], true) == null
	if not first_special_released or replacement_special == null or replacement_count != 2 or not replacement_plain_blocked:
		failures.append("releasing the special view opens one special and one normal slot")

	area.clear_barrages()
	area.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS BG-35: independent special cap, compatible multi-trait instance, shared normal capacity, and release")
	else:
		push_error("FAIL BG-35: %s" % "; ".join(failures))
	quit(0 if failures.is_empty() else 1)


## 构造只用于本次同屏容量回归的原句。
func _make_speech(sentence_id: String, sentence_text: String) -> LevelSpeech:
	var speech := LevelSpeech.new()
	speech.original_sentence_id = sentence_id
	speech.text = sentence_text
	speech.tendency_id = "orthodox"
	speech.appearance_weight = 1.0
	return speech


## 使用当前战斗区尺寸，避免测试依赖固定父节点层级。
func _set_area_rect(area: BarrageArea) -> void:
	area.anchor_left = 0.0
	area.anchor_top = 0.0
	area.anchor_right = 0.0
	area.anchor_bottom = 0.0
	area.offset_left = 448.0
	area.offset_top = 72.0
	area.offset_right = 1472.0
	area.offset_bottom = 832.0


## 准备易读的实际运行画布，展示一个双特性实例和一个普通实例。
func _prepare_visual_canvas() -> void:
	var background := ColorRect.new()
	background.size = Vector2(1920.0, 1080.0)
	background.color = Color("#111822")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	root.move_child(background, 0)
	var title := Label.new()
	title.position = Vector2(448.0, 12.0)
	title.size = Vector2(1024.0, 44.0)
	title.text = "BG-35 · 特殊实例上限 1 · 双特性实例仍只占一个特殊名额"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#f4f6fa"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)
	var status := Label.new()
	status.position = Vector2(448.0, 844.0)
	status.size = Vector2(1024.0, 56.0)
	status.text = "特性实例：1 / 1（假牌 + 水军反击）    普通前景：2 / 2（同一条特殊实例也计入）"
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", Color("#cbd8e8"))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(status)


## 从真实 Godot 渲染帧保存本卡预览；headless 测试只验证逻辑。
func _save_visual_evidence(failures: Array[String]) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var evidence_directory: String = ProjectSettings.globalize_path("res://docs/3. BarrageGeneration/evidence")
	DirAccess.make_dir_recursive_absolute(evidence_directory)
	var screenshot_error: Error = root.get_texture().get_image().save_png(
		ProjectSettings.globalize_path(SCREENSHOT_PATH)
	)
	if screenshot_error != OK:
		failures.append("Godot rendered preview saves (%s)" % error_string(screenshot_error))
	else:
		print("BG-35 visual evidence: %s" % ProjectSettings.globalize_path(SCREENSHOT_PATH))
	# 让图形 smoke 的实际特殊和普通实例保持在屏幕上供目视检查。
	await create_timer(3.0, true).timeout
