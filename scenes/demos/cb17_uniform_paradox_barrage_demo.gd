extends Control

const LOGICAL_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const BOARD_RECT: Rect2 = Rect2(Vector2(448.0, 72.0), Vector2(1024.0, 828.0))
const LEVEL_PROFILE: LevelProfile = preload("res://data/level_configuration/level_001.tres")
const WINDOW_CONFIG: ContradictionWindowConfig = preload("res://systems/contradiction_break/contradiction_window_config.tres")
const BREAK_SYSTEM_SCRIPT: Script = preload("res://systems/contradiction_break/contradiction_break_system.gd")
const PRESENTATION_SCENE: PackedScene = preload("res://systems/contradiction_break/contradiction_barrage_presentation.tscn")
const EVIDENCE_DIR: String = "res://docs/12. ContradictionBreak/evidence/CB-17_2026-10-19"

var _presentation: Control
var _break_system: ContradictionBreakSystem
var _capture_file_name: String = ""
var _long_text_preview: bool = false


func _ready() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	_long_text_preview = user_args.has("--cb17-capture-long")
	if user_args.has("--cb17-capture"):
		_capture_file_name = "cb17_level_001_1280x720.png"
	elif _long_text_preview:
		_capture_file_name = "cb17_long_text_layout_1280x720.png"
	if not _capture_file_name.is_empty():
		# 截图按实际窗口 1280×720 输出，逻辑画布仍沿用1920×1080。
		get_tree().root.size = Vector2i(1280, 720)
	await get_tree().process_frame
	_build_demo_layout()
	call_deferred("_start_real_level_preview")


## 用真实一关资源和既有矛盾、弹幕、准星组件搭出独立演示，不启动正式战斗流程。
func _build_demo_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_add_color_rect(Rect2(Vector2.ZERO, LOGICAL_SIZE), Color("#0A1018"))
	_add_panel(Rect2(Vector2(0.0, 72.0), Vector2(424.0, 828.0)), Color("#111A25"), Color("#324353"), 1)
	_add_panel(Rect2(BOARD_RECT.position, BOARD_RECT.size), Color("#111A25"), Color("#50677C"), 1)
	_add_panel(Rect2(Vector2(1496.0, 72.0), Vector2(424.0, 828.0)), Color("#111A25"), Color("#324353"), 1)
	_add_panel(Rect2(Vector2(0.0, 920.0), Vector2(1920.0, 160.0)), Color("#0F1721"), Color("#27394B"), 1)
	_add_label("矛盾击破", Rect2(Vector2(448.0, 6.0), Vector2(1024.0, 58.0)), 34, Color("#F5F2E9"))
	_add_label("T6  ·  10秒窗口  ·  一次射击机会", Rect2(Vector2(448.0, 924.0), Vector2(1024.0, 42.0)), 24, Color("#F4D27A"))
	_add_label("移动准星查看统一瞄准反馈", Rect2(Vector2(448.0, 970.0), Vector2(1024.0, 40.0)), 22, Color("#CBD5E1"))
	_add_label("六句共用外观；命中与结果仍由既有规则决定。", Rect2(Vector2(448.0, 1013.0), Vector2(1024.0, 34.0)), 18, Color("#8EA0B2"))
	_add_host_panels()
	_presentation = PRESENTATION_SCENE.instantiate() as Control
	if _presentation == null:
		push_error("CB-17 demo: presentation scene failed to instantiate")
		return
	_presentation.position = BOARD_RECT.position
	_presentation.size = BOARD_RECT.size
	add_child(_presentation)
	_add_label(
		"长句排版样例 · 测试文本，不属于关卡候选" if _long_text_preview else "第一关 · 费米",
		Rect2(Vector2(1088.0, 82.0), Vector2(350.0, 34.0)), 16, Color("#AEBFCE"), HORIZONTAL_ALIGNMENT_RIGHT
	)


## 生成左右主播信息栏；对手信息沿用第一关真实 LevelProfile。
func _add_host_panels() -> void:
	_add_label("对手主播", Rect2(Vector2(32.0, 92.0), Vector2(360.0, 44.0)), 21, Color("#8EA0B2"))
	var portrait := TextureRect.new()
	portrait.position = Vector2(52.0, 148.0)
	portrait.size = Vector2(320.0, 440.0)
	portrait.texture = LEVEL_PROFILE.streamer_portrait
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	_add_label(LEVEL_PROFILE.streamer_name, Rect2(Vector2(32.0, 606.0), Vector2(360.0, 50.0)), 26, Color("#F5F2E9"))
	_add_label("直播主题 · " + LEVEL_PROFILE.stream_topic, Rect2(Vector2(32.0, 660.0), Vector2(360.0, 38.0)), 17, Color("#AEBFCE"))
	_add_label("挑战主播", Rect2(Vector2(1528.0, 92.0), Vector2(360.0, 44.0)), 21, Color("#8EA0B2"))
	_add_panel(Rect2(Vector2(1588.0, 164.0), Vector2(240.0, 240.0)), Color("#1A2735"), Color("#4B657A"), 2)
	_add_label("你", Rect2(Vector2(1588.0, 164.0), Vector2(240.0, 240.0)), 88, Color("#D9E7F1"))
	_add_label("认真判断每句矛盾", Rect2(Vector2(1528.0, 438.0), Vector2(360.0, 50.0)), 20, Color("#D5DEE7"))
	_add_label("准星命中反馈统一\n射击与结果沿用既有流程", Rect2(Vector2(1528.0, 496.0), Vector2(360.0, 112.0)), 18, Color("#95A7B8"))


## 从 CB-13 系统取固定一真五假；压力模式只替换内存副本的一条测试长句。
func _start_real_level_preview() -> void:
	if _presentation == null:
		get_tree().quit(1)
		return
	_break_system = BREAK_SYSTEM_SCRIPT.new() as ContradictionBreakSystem
	add_child(_break_system)
	if not _break_system.load_level_content(LEVEL_PROFILE):
		push_error("CB-17 demo: LevelProfile failed to load into the existing contradiction system")
		get_tree().quit(1)
		return
	var candidates: Array[LevelContradiction] = _break_system.get_fixed_paradox_candidates()
	if candidates.size() != 6:
		push_error("CB-17 demo: first-level source did not provide six real candidates")
		get_tree().quit(1)
		return
	var true_lines: Array[LevelContradiction] = [candidates[0]]
	var false_lines: Array[LevelContradiction] = []
	for index: int in range(1, candidates.size()):
		false_lines.append(candidates[index])
	if _long_text_preview:
		var stress_line: LevelContradiction = false_lines[4].duplicate(true) as LevelContradiction
		stress_line.text = "你根本就不是猫，因为真正的猫不会在直播开始后停下来问观众今晚要不要一起去看流星雨！"
		false_lines[4] = stress_line
	if not bool(_presentation.call("present_candidates", LEVEL_PROFILE, true_lines, false_lines, WINDOW_CONFIG)):
		push_error("CB-17 demo: the existing BarrageArea rejected the six candidate presentation")
		get_tree().quit(1)
		return
	print("CB17 PRESENTATION_READY candidates=%d long_text_sample=%s" % [candidates.size(), str(_long_text_preview)])
	if not _capture_file_name.is_empty():
		call_deferred("_capture_real_godot_frame")


## 只在截图模式移动触屏准星，确认目标矩形与统一反馈后保存真实 Godot 渲染帧。
func _capture_real_godot_frame() -> void:
	await get_tree().process_frame
	var view_value: Variant = _presentation.call("get_visible_views")
	var views: Array = view_value if view_value is Array else []
	if views.is_empty():
		push_error("CB-17 capture: no visible contradiction views")
		get_tree().quit(1)
		return
	var target := views[views.size() / 2] as BarrageView
	var target_transform: Transform2D = target.get_global_transform_with_canvas()
	var target_viewport_center: Vector2 = target_transform * (target.size * 0.5)
	var reticle := _presentation.call("get_aim_reticle") as AimReticle
	reticle.move_touch_aim(target_viewport_center, 144.0)
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() == "headless":
		push_error("CB-17 capture requires a real Godot window renderer")
		get_tree().quit(1)
		return
	var evidence_directory: String = ProjectSettings.globalize_path(EVIDENCE_DIR)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(evidence_directory)
	if directory_error != OK:
		push_error("CB-17 capture: evidence directory creation failed with %s" % directory_error)
		get_tree().quit(1)
		return
	var screenshot_path: String = evidence_directory.path_join(_capture_file_name)
	var screenshot: Image = get_viewport().get_texture().get_image()
	var screenshot_error: Error = screenshot.save_png(screenshot_path)
	if screenshot_error != OK:
		push_error("CB-17 capture: PNG save failed with %s" % screenshot_error)
		get_tree().quit(1)
		return
	print("CB17 SCREENSHOT path=%s image=%s window=%s" % [
		EVIDENCE_DIR.path_join(_capture_file_name), str(screenshot.get_size()), str(get_tree().root.size)
	])
	get_tree().quit(0)


func _add_panel(rect: Rect2, fill_color: Color, edge_color: Color, border_width: int) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = edge_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel


func _add_color_rect(rect: Rect2, fill_color: Color) -> ColorRect:
	var color_rect := ColorRect.new()
	color_rect.position = rect.position
	color_rect.size = rect.size
	color_rect.color = fill_color
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(color_rect)
	return color_rect


func _add_label(
	label_text: String,
	rect: Rect2,
	font_size: int,
	font_color: Color,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
) -> Label:
	var label := Label.new()
	label.text = label_text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
