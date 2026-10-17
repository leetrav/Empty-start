extends Control

var _prompt: Label
var _progress: ProgressBar
var _rings: Array[Dictionary] = []


# DD 自有提示层；输入透传给根流程，沿用现有主题，不承接战斗 HUD 业务。
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -580
	panel.offset_right = 580
	panel.offset_top = -150
	panel.offset_bottom = -45
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 28)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_prompt)
	_progress = ProgressBar.new()
	_progress.max_value = 1.0
	_progress.show_percentage = false
	_progress.custom_minimum_size.y = 9
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_progress)


# 展示真实阶段及衰减/收束进度，不通过提示文本驱动业务状态。
func show_phase(prompt: String, progress: float) -> void:
	_prompt.text = prompt
	_progress.value = clampf(progress, 0.0, 1.0)


# 每次真实输入立即产生局部涟漪，即使容量已满也有可感知反馈。
func respond(point: Vector2) -> void:
	if _rings.size() >= 8:
		_rings.pop_front()
	_rings.append({"point": point, "age": 0.0})
	queue_redraw()


# 原生暂停模式冻结涟漪和进度；仅保留短暂的表现状态。
func _process(delta: float) -> void:
	for index: int in range(_rings.size() - 1, -1, -1):
		_rings[index]["age"] += delta
		if float(_rings[index]["age"]) >= 0.4:
			_rings.remove_at(index)
	queue_redraw()


# 轮廓只表达本次输入已接受，使用已有界面配色，不新增正式美术。
func _draw() -> void:
	for ring: Dictionary in _rings:
		var progress := float(ring["age"]) / 0.4
		draw_arc(ring["point"], lerpf(18.0, 92.0, progress), 0.0, TAU, 48,
			Color(1.0, 0.85, 0.47, 1.0 - progress), 4.0, true)
